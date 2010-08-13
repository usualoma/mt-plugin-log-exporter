# Copyright (c) 2010 ToI Inc, All rights reserved.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# $Id$

package MT;
use Data::Dumper;

sub dumper {
	my ($self) = @_;
	$self->log(Dumper($_[1]));
}

package LE;
use Data::Dumper;

sub dumper {
	MT->instance->log(Dumper($_[1]));
}

package LogExporter;

use strict;
use warnings;

use Data::Dumper;
use File::Spec;

our %types = qw(
	info     1
	warning  2
	error    4
	security 8
	debug    16
);

sub plugin {
	MT->component('LogExporter');
}

sub loggers {
	my ($type) = @_;

	my $loggers = MT->request('log_exporter_loggers');

	if (! $loggers) {
		require YAML::Tiny;
		my $config = File::Spec->catfile(&plugin->{full_path}, 'logger.yaml');
		my $yaml = YAML::Tiny->read($config);

		$loggers = $yaml->[0];
		MT->request('log_exporter_loggers', $loggers);
	}

	if (my $data = $loggers->{types}{$type}) {
		my $logger   = $loggers->{'loggers'}{$data->{logger}};

		return $logger;
	}
	else {
		return;
	}
}

sub log_handle {
	my ($type) = @_;

	my $logger = &loggers($type);

	if ($logger) {
		my $filename = $logger->{filename};
		if ($filename !~ m{\A/}) {
			$filename = File::Spec->catfile(
				&plugin->{full_path}, 'log', $filename
			);
		}

		my $handles = MT->request('log_exporter_handles') || {};
		my $fh = $handles->{$filename};
		if (! $fh) {
			if (-e $filename) {
				if (my $size = $logger->{'size'}) {
					my $max = $logger->{'max'} || 0;
					if ((stat($filename))[7] >= $size) {
						my @files = sort({
							my ($a_num) = ($a =~ m{(\d+$)});
							my ($b_num) = ($b =~ m{(\d+$)});
							$b_num <=> $a_num;
						} glob($filename . '.*'));
						foreach my $file (@files) {
							my ($base, $num) = ($file =~ m{(.*?)(\d+$)});

							$num++;
							if ($max && $num > $max) {
								unlink($file);
							}
							else {
								print($base . $num);
								rename($file, $base . $num);
							}
						}
						rename($filename, $filename . '.1');
					}
				}
			}

			open($fh, '>>', $filename);
			$handles->{$filename} = $fh;
			MT->request('log_exporter_handles', $handles);
		}

		return $fh;
	}
	else {
		return;
	}
}

sub append_log {
	my ($type, $message) = @_;

	if (my $fh = &log_handle($type)) {
		$message ||= '';
		$message =~ s{(\r|\n)*$}{};
		print($fh sprintf("[%s] %s\n", $type, $message));
	}
}


sub take_down {
	my $app = MT->instance;

	foreach my $message (@{ $app->{'trace'} || [] }) {
		&append_log('trace', $message);
	}
}

sub log_post_save {
	my ($cb, $obj) = @_;

	my $type;
	for my $t (keys(%types)) {
		$type = $t if $types{$t} == $obj->level;
	}

	&append_log($type, $obj->message);
}


sub _hdlr_log {
    my ($ctx, $args) = @_;
	my $name = $args->{'name'} || $args->{'var'} || '';
	my $value = $args->{'value'} || '';
	my $scalar = $args->{'scalar'} || '';
	my $dump = $args->{'dump'};

	use Data::Dumper;

	if ($name) {
		$value = $ctx->var($name);
	}

	if ($dump) {
		$value = Dumper($value);
	}

	MT->instance->log($value);

	'';
}

1;
