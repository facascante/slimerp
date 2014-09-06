package Log;

require Exporter;
@ISA    = qw(Exporter Log::Log4perl);
@EXPORT = qw( get_logger LOGDIE TRACE DEBUG INFO WARN ERROR FATAL );
@EXPORT_OK = qw( get_logger LOGDIE TRACE DEBUG INFO WARN ERROR FATAL );

use strict;
use lib '.', '..';
use Defs;
use Log::Log4perl;
Log::Log4perl->wrapper_register(__PACKAGE__);

my $LOG_CONF = $Defs::LOG_CONF || qq {
log4perl.oneMessagePerAppender = 1

log4perl.rootLogger = ERROR, Screen

log4perl.appender.Screen = Log::Log4perl::Appender::Screen
log4perl.appender.Screen.stderr = 1
log4perl.appender.Screen.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Screen.layout.ConversionPattern = %M | %m%n
};

# initialize the logger configuration
Log::Log4perl::init(\$LOG_CONF);


sub get_logger {
    return Log::Log4perl->get_logger(@_);
}

sub TRACE {
    my $msg = join(' ', @_);
    my $logger = Log::Log4perl->get_logger();
    $logger->trace($msg);
}

sub DEBUG {
    my $msg = join(' ', @_);
    my $logger = Log::Log4perl->get_logger();
    $logger->debug($msg);
}

sub INFO {
    my $msg = join(' ', @_);
    my $logger = Log::Log4perl->get_logger();
    $logger->info($msg);
}

sub WARN {
    my $msg = join(' ', @_);
    my $logger = Log::Log4perl->get_logger();
    $logger->warn($msg);
}

sub ERROR {
    my $msg = join(' ', @_);
    my $logger = Log::Log4perl->get_logger();
    $logger->error($msg);
}

sub FATAL {
    my $msg = join(' ', @_);
    my $logger = Log::Log4perl->get_logger();
    $logger->fatal($msg);
}

sub LOGDIE {
    my $msg = join(' ', @_);
    my $logger = Log::Log4perl->get_logger();
    $logger->logconfess();
    $logger->fatal($msg) and die $msg;
}
