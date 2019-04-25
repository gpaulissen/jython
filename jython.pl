#!/usr/bin/env perl

use strict;
use warnings;
use Config;
use Cwd;
use File::Basename;
use File::Spec;
use File::Find;

# PROTOTYPES

sub main();
sub process_command_line();
sub setup_rf_classpath();
sub setup_java();
sub setup_webdrivers();
sub find_webdrivers();
sub bad_option($);
sub print_help();
sub restore_streams();
sub redirect_streams();
sub add_to_path($$@);

# see jython/src/shell/jython.py

my $program;
my $log_file;
my $ini_file;
my ($classpath, @java_props, @java_args, $help, @jython_args) = (exists($ENV{'CLASSPATH'}) ? $ENV{'CLASSPATH'} : '');

main();

sub main()
{
    $program = 'java';
    $log_file = File::Spec->catfile(dirname($0), 'jython.log');

    warn "jython runtime log: $log_file\n";
    
    redirect_streams();

    eval {
        $| = 1; # autoflush
    
        print "# jython runtime log\n";
    
        my $timestamp = localtime(time);

        print $timestamp, "\n\n";
    
        process_command_line();

        if (defined($help)) {
            print_help();
        }

        setup_rf_classpath();
        setup_java();
        setup_webdrivers();
        
        print "PATH: $ENV{'PATH'}\n";
        print "CLASSPATH: $ENV{'CLASSPATH'}\n";
        print "command: $program @java_props @java_args @jython_args\n";
        print "\n*** robotframework starting now ***\n";
    };
    
    restore_streams();
    
    if ($@) {
        warn $@, qq(\n);
        exit 1;
    }  

    if (system($program, @java_props, @java_args, @jython_args) != 0) {
        die "\nERROR: system($program, @java_props, @java_args, @jython_args) failed: $?";
    }    
}

sub process_command_line()
{
    print "*** command line ***\n";
    print "current directory: ", cwd, "\n";
    print "\$0: $0\n";
    
    my $i;

    # some debugging
    for ($i = 1; $i <= @ARGV; ++$i) {
        my $arg = $ARGV[$i-1];
        
        print "argument $i: $arg\n";
    }
    
    for ($i = 0; $i < @ARGV; ++$i) {
        my $arg = $ARGV[$i];
        
        if ($arg =~ m/^-D/) {
            push(@java_props, $arg);
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
    print "\@java_props: @java_props\n";
    print "\@java_args: @java_args\n";
    print "\@jython_args: @jython_args\n";

    print "\n*** environment ***\n";
    foreach my $env (sort(keys %ENV)) {
        print("$env=$ENV{$env}\n");
    }
}

sub setup_rf_classpath()
{
    die "Environment variable RF_JAR should be the robotframework jar"
        unless (grep(/^RF_JAR$/, keys %ENV) && -e $ENV{'RF_JAR'} && $ENV{'RF_JAR'} =~ m/\brobotframework.*\.jar$/);
    
    if (-f 'pom.xml') {
        my $cp_file = File::Spec->catfile('target', 'classpath.txt');
        
        my $cmd = "mvn dependency:build-classpath -Dmdep.outputFile=$cp_file";
    
        if (system($cmd) != 0) {
            die "\nERROR: system($cmd) failed: $?";
        }

        open(my $fh, '<', $cp_file);
        $classpath = <$fh>;
        close $fh;
    } else {
        $classpath = $ENV{'RF_JAR'};
    }

    # Add custom libraries not in the Maven classpath, see Maven Robotframework plugin extraPathDirectories
    foreach my $env (sort(grep(/^RF_(.+)_JAR$/, keys %ENV))) {
        add_to_path(\$classpath, 1, $ENV{$env});
    }
    
    # classpath may be too long for the command line so just define CLASSPATH
    $ENV{'CLASSPATH'} = ''
        unless(exists($ENV{'CLASSPATH'}));
    $ENV{'CLASSPATH'} .= $Config{path_sep} . $classpath;
    push(@java_args, 'org.python.util.jython');
}

sub setup_java()
{
    return
        unless (exists($ENV{'JAVA_HOME'}));
    
    my $java_bindir = File::Spec->catdir($ENV{'JAVA_HOME'}, 'bin');

    add_to_path(\$ENV{'PATH'}, 0, $java_bindir);
}

sub setup_webdrivers() 
{
    return
        unless (exists $ENV{'KATALON_HOME'} && -d $ENV{'KATALON_HOME'});
    
    find(\&find_webdrivers, File::Spec->catdir($ENV{'KATALON_HOME'}, 'configuration', 'resources', 'drivers'));
}

sub find_webdrivers()
{
    my $exe = $Config{'_exe'};
    my $webdriver = undef;
    
    if ($_ eq "chromedriver$exe") {
        $webdriver = 'webdriver.chrome.driver';
    } elsif ($_ eq "MicrosoftWebDriver$exe") {
        $webdriver = 'webdriver.edge.driver';
    } elsif ($_ eq "geckodriver$exe") {
        $webdriver = 'webdriver.gecko.driver';
    } elsif ($_ eq "IEDriverServer$exe") {
        $webdriver = 'webdriver.ie.driver';
    }
        
    if (defined($webdriver)) {
        my $file = File::Spec->canonpath($File::Find::name);
        
        printf STDOUT ("%s: %s\n", $webdriver, $file);
        
        push(@java_props, sprintf("-D%s=%s", $webdriver, $file));
        add_to_path(\$ENV{'PATH'}, 0, File::Spec->canonpath($File::Find::dir));
    }
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

sub add_to_path($$@)
{
    my ($r_path, $end, @files) = @_;

    $$r_path = ''
        unless defined($$r_path);
    
    foreach my $file (@files) {
        die "File/directory '$file' does not exist"
            unless -e $file;
        
        $$r_path = ($end ? $$r_path . $Config{path_sep} . $file : $file . $Config{path_sep} . $$r_path);
    }
}
