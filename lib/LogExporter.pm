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

package MT;
use Data::Dumper;
use B::Deparse;

sub dumper {
	my ($self) = @_;
	$self->log(Dumper($_[1]));
}

sub c2t {
	my ($self) = @_;
	my $bd = B::Deparse->new;
	$self->log($bd->coderef2text($_[1]));
}

package LE;
use Data::Dumper;
use B::Deparse;

sub dumper {
	MT->instance->log(Dumper($_[1]));
}

sub c2t {
	my $bd = B::Deparse->new;
	MT->instance->log($bd->coderef2text($_[1]));
}

package LogExporter;

use strict;
use warnings;

use Data::Dumper;
use File::Spec;
use Term::ANSIColor;

our %types = qw(
	info     1
	warning  2
	error    4
	security 8
	debug    16
);

sub init_app {
	$Data::ObjectDriver::PROFILE = 1;
	$Data::ObjectDriver::PROFILE;
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
	&filename($logger->{filename});
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
        next if $query =~ m/^RAMCACHE_(GET|ADD)/;
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


sub viewer {
	my $app = shift;

	my $loggers = &loggers;
	my $logger  = $loggers->{(keys(%$loggers))[0]};
	my $filename = &filename($logger->{filename});

	my $server_path = $app->server_path() || "";
	my $cfg = $app->config;
	my $cgi_path = $cfg->CGIPath;
	$filename =~ s{$server_path}{$cgi_path};

	MT->log($filename);

	my %param = (
		filename => $filename,
	);

	plugin->load_tmpl('log_exporter_viewer.tmpl', \%param);
}

1;
