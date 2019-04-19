#!/usr/bin/env perl

use strict;
use warnings;
use Config;
use File::Spec;

# PROTOTYPES

sub main();
sub process_command_line();
sub create_ini_file();
sub setup_rf_lib_jars();
sub setup_java();
sub bad_option($);
sub print_help();
sub restore_streams();
sub redirect_streams();

# see jython/src/shell/jython.py

my $program = $0;
my $log_file;
my $ini_file;
my ($classpath, @java_args, $help, @jython_args);
my $launch4j = ( exists($ENV{'LAUNCH4J'}) ? 1 : 0 );

main();

sub main()
{
    # robotframework.exe is created by launch4j
    $program =~ s/^(.*)\bjython(\.exe|\.pl)?$/$1 . 'robotframework'/e;
    $log_file = $program . '.log';

    redirect_streams();

    $| = 1; # autoflush
    
    print "# robotframework runtime log\n";
    
    my $timestamp = localtime(time);

    print $timestamp, "\n\n";
    
    process_command_line();

    if (defined($help)) {
        print_help();
    }

    print "\n*** robotframework ***\ncommand: $program @jython_args\n";
    
    create_ini_file();
    setup_rf_lib_jars();
    # setup_java();
                     
    print "\n*** robotframework starting now ***\n";

    restore_streams();

    if (system($program, @jython_args) != 0) {
        die "ERROR: system($program, @jython_args) failed: $?";
    }    
}

sub process_command_line()
{
    print "*** command line ***\n";
    print "\$0: $0\n";

    my $i;

    # some debugging
    for ($i = 0; $i < @ARGV; ++$i) {
        my $arg = $ARGV[$i];
        
        print "argument $i: $arg\n";
    }
    
    for ($i = 0; $i < @ARGV; ++$i) {
        my $arg = $ARGV[$i];
        
        if ($arg =~ m/^-D/) {
            push(@java_args, $arg);
        } elsif ($arg =~ m/^(-J-classpath|-J-cp)$/) {
            bad_option("Argument expected for -J-classpath option")
                unless ++$i < @ARGV;
            $arg = $ARGV[$i];
            bad_option("Bad option for -J-classpath")
                if ($arg =~ m/^-/);
            $classpath = $arg;
        } elsif ($arg =~ m/^-J/) {
            push(@java_args, substr($arg, 2));
        } elsif ($arg eq "--print") {
            bad_option("Bad option $arg");
        } elsif ($arg eq "-h" || $arg eq "--help") {
            $help = 1;
        } elsif ($arg =~m/^--(boot|jdb|profile)$/) {
            bad_option("Bad option $arg");
        } elsif ($arg =~ m/^-[BEisSuvV3]/) {
            push(@jython_args, $arg);
        } elsif ($arg eq  "--") {
            ++$i;
            last;
        } else {
            last;
        }
    }
    push(@jython_args, @ARGV[$i .. $#ARGV]);

    print "\n*** parsed arguments ***\n";
    print "\$classpath: $classpath\n"
        if (defined($classpath));
    print "\@java_args: @java_args\n";
    print "\@jython_args: @jython_args\n";

    print "\n*** environment ***\n";
    foreach my $env (sort(keys %ENV)) {
        print("$env=$ENV{$env}\n");
    }
}

sub create_ini_file()
{
    die "Environment variable RF_JAR should be the robotframework jar."
        unless (grep(/^RF_JAR$/, keys %ENV) && -e $ENV{'RF_JAR'} && $ENV{'RF_JAR'} =~ m/\brobotframework.*\.jar$/);
    
    # Additional JVM options at runtime
    # When you create a wrapper or launcher all configuration details are
    # compiled into the executable and cannot be changed without recreating it
    # or hacking with a resource editor. Launch4j 2.1.2 introduces a new
    # feature that allows to pass additional JVM options at runtime from an
    # .l4j.ini file. Now you can specify the options in the configuration
    # file, ini file or in both, but you cannot override them. The ini file's
    # name must correspond to the executable's (myapp.exe :
    # myapp.l4j.ini). The arguments should be separated with spaces or new
    # lines, environment variable expansion is supported, for example:
    #
    # # Launch4j runtime config
    # -Dswing.aatext=true
    # -Dsomevar="%SOMEVAR%"
    # -Xms16m
        
    my $ini_file = $program . ".l4j.ini";

    open(my $fh, '>', $ini_file);

    print "launch4j runtime settings: $ini_file\n";    

    print $fh "# Launch4j runtime config\n";
    
    foreach (@java_args) {
        print $fh "$_\n";
    }

    close $fh;
}    

sub setup_rf_lib_jars()
{
    foreach my $env (sort(grep(/^RF_(.+)_JAR$/, keys %ENV))) {
        my $jar = $ENV{$env};

        die "Jar file '$jar' does not exist"
            unless -f $jar;
        
        $classpath = ( defined($classpath) ? $classpath . $Config{path_sep} . $jar : $jar );
    }
    $ENV{'RF_LIB_JARS'} = ( defined($classpath) ? $classpath : '' );
}

sub setup_java()
{
    return
        unless (exists($ENV{'JAVA_HOME'}));
    
    my $java_bindir = File::Spec->catdir($ENV{'JAVA_HOME'}, 'bin');

    $ENV{'PATH'} = (exists($ENV{'PATH'}) ? $java_bindir . $Config{path_sep} . $ENV{'PATH'} : $java_bindir);
}

sub bad_option($)
{
    my ($msg) = @_;
    
    warn <<'MESSAGE';
$msg
usage: jython [option] ... [-c cmd | -m mod | file | -] [arg] ...
Try `jython -h' for more information.
MESSAGE
    
    exit(2);
}

sub print_help()
{    
    warn <<'HELP';
Jython launcher-specific options:
-Dname=value : pass name=value property to Java VM (e.g. -Dpython.path=/a/b/c)
-Jarg    : pass argument through to Java VM (e.g. -J-Xmx512m)
--boot   : speeds up launch performance by putting Jython jars on the boot classpath
--help   : this help message
--jdb    : run under JDB java debugger
--print  : print the Java command with args for launching Jython instead of executing it
--profile: run with the Java Interactive Profiler (http://jiprof.sf.net)
--       : pass remaining arguments through to Jython
Jython launcher environment variables:
JAVA_MEM   : Java memory size as a java option e.g. -Xmx600m or just 600m
JAVA_STACK : Java stack size as a java option e.g. -Xss5120k or just 5120k
JAVA_OPTS  : options to pass directly to Java
JAVA_HOME  : Java installation directory
JYTHON_HOME: Jython installation directory
JYTHON_OPTS: default command line arguments
HELP

    exit(1);
}

sub redirect_streams()
{
  open OLDOUT,">&STDOUT" || die "Can't duplicate STDOUT: $!";
  open OLDERR,">&STDERR" || die "Can't duplicate STDERR: $!";
  open(STDOUT,">> $log_file");
  open(STDERR,">&STDOUT");
}

sub restore_streams()
{
  close(STDOUT) || die "Can't close STDOUT: $!";
  close(STDERR) || die "Can't close STDERR: $!";
  open(STDERR, ">&OLDERR") || die "Can't restore stderr: $!";
  open(STDOUT, ">&OLDOUT") || die "Can't restore stdout: $!";
  # To suppress warnings like
  #
  # Name "main::OLDOUT" used only once: possible typo at jython.pl line 203.
  # Name "main::OLDERR" used only once: possible typo at jython.pl line 204.
  if (0) {
      close OLDOUT;
      close OLDERR;
  }
}
