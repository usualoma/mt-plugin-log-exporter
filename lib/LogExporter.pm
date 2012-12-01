# Copyright (c) 2011 ToI Inc, All rights reserved.
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

package LogExporter;

use strict;
use warnings;

use Data::Dumper;
use File::Spec;
use Term::ANSIColor;

our %types = qw(
	1  info
	2  warning
	4  error
	8  security
	16 debug
);

sub init_app {
	my $loggers = &load_loggers;
	if ($loggers->{types}{query}) {
	    $Data::ObjectDriver::PROFILE = 1;
	    $Data::ObjectDriver::PROFILE;
    }
}

sub plugin {
	MT->component('LogExporter');
}

sub load_loggers {
	my $loggers = MT->request('log_exporter_loggers');

	if (! $loggers) {
		require YAML::Tiny;
		my $config = File::Spec->catfile(&plugin->{full_path}, 'logger.yaml');
		my $yaml = YAML::Tiny->read($config);

		$loggers = $yaml->[0];
		MT->request('log_exporter_loggers', $loggers);
	}

    $loggers;
}

sub loggers {
	my ($type) = @_;

	my $loggers = &load_loggers;

	if (! $type) {
		return $loggers->{'loggers'};
	}
	elsif (my $data = $loggers->{types}{$type}) {
		my $logger   = $loggers->{'loggers'}{$data->{logger}};

		return $logger;
	}
	else {
		return;
	}
}

sub filename {
	my ($filename) = @_;

	if ($filename !~ m{\A/}) {
		$filename = File::Spec->catfile(
			&plugin->{full_path}, 'log', $filename
		);
	}

	$filename;
}

sub log_filename {
	my ($type) = @_;

	my $logger = &loggers($type)
		or return;
	my $name = &filename($logger->{filename});

    if (my $size = $logger->{size}) {
        my $max  = $logger->{max} || 0;
        if ((stat($name))[7] > $size) {
            for my $f (reverse(sort(glob($name . '.*')))) {
                my ($index) = ($f =~ m/(\d+)$/);
                if ($max && $index >= $max) {
                    unlink($f);
                    next;
                }

                my $to = $f;
                $to =~ s/(\d+)$/$1+1/e;
                rename($f, $to);
            }

            rename($name, $name . '.1');
        }
    }

    $name;
}

sub log_colors {
	my ($type) = @_;

	my $loggers = &load_loggers;

	if (my $data = $loggers->{types}{$type}) {
        $data->{ansi_color};
	}
	else {
		return;
	}
}

sub append_log {
	my ($type, $message) = @_;

	if (my $filename = &log_filename($type)) {
		$message ||= '';
		$message =~ s{(\r|\n)*$}{};

		open(my $fh, '>>', $filename)
			or die $!;

        my $colors = &log_colors($type);

		print($fh '[', $type, '] ');

		print($fh color(@$colors)) if $colors;
        print($fh $message, "\n");
		print($fh color('reset')) if $colors;

		close($fh)
			or die $!;
	}
}


sub take_down {
	my $app = MT->instance;

	foreach my $query (@{ Data::ObjectDriver->profiler->query_log }) {
        next if $query =~ m/^RAMCACHE_(GET|ADD|DELETE)/;
		&append_log('query', $query);
	}

	foreach my $message (@{ $app->{'trace'} || [] }) {
		&append_log('trace', $message . ' query_string: ' . $app->param->query_string);
	}

    # color test
    if (0) {
        for my $k (qw(info warning error security debug query trace)) {
	        &append_log($k, $k);
        }
    }
}

sub log_post_save {
	my ($cb, $obj) = @_;
	&append_log($types{$obj->level}, $obj->message);
}


sub _hdlr_log {
	my ($ctx, $args) = @_;
	my $name = $args->{'name'} || $args->{'var'} || '';
	my $value = $args->{'value'} || '';
	my $dump = $args->{'dump'};

	if ($name) {
		$value = $ctx->var($name);
	}

	if ($dump) {
		local $Data::Dumper::Deparse = 1;
		$value = Dumper($value);
	}

	MT->instance->log($value);

	'';
}


sub viewer {
	my $app = shift;

	my $loggers = &loggers;
	my $logger  = $loggers->{(keys(%$loggers))[0]};
	my $filename = &filename($logger->{filename});

	my $server_path = $app->server_path() || "";
	my $cfg = $app->config;
	my $cgi_path = $cfg->CGIPath;
	$filename =~ s{$server_path}{$cgi_path};

	my %param = (
		filename => $filename,
	);

	plugin->load_tmpl('log_exporter_viewer.tmpl', \%param);
}

1;
