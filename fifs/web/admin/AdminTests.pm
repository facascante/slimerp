package AdminTests;

use Exporter 'import';
@EXPORT = @EXPORT_OK = qw(show_tests run_tests);

use lib '../..';
use strict;
use warnings;

use TAP::Harness;
use Capture::Tiny qw(capture);

use Log;

sub show_tests{
    my $test_sets = _get_tests();
    
    my $body = "<h3>Choose your test sets to run </h3>";
    
    $body .= q[<form action="index.cgi" method="post">];
    $body .= q[<input type="hidden" name="action" value="TESTS_RUN">];
    
    # verbosity selector
    $body .= q[ 
        <label for="verbosity">Verbosity</label>
        <select name="verbosity">
            <option value="1">Print individual test results</option>
            <option selected value="0">Normal</option>
            <option value="-1">Suppress some test output (mostly failures while tests are running)</option>
            <option value="-2">Suppress everything but the tests summary</option>
        </select><br>
    ];

    # Test checkboxes
    $body .= q[<label for="test_set">Selected Tests</label><br>];
    foreach my $test_set (keys %{$test_sets}){
        my $description = $test_sets->{$test_set}->{'description'} || "$test_set tests";
        $body .= qq[<input type="checkbox" name="test_set" value="$test_set">$description<br>];
    }
    $body .= '<input type="submit" name="submit" value="Run Tests">';
    $body .= '</form>';
    
    return $body;
}


sub run_tests{
    my ($test_sets, $verbosity) = @_;
    
    my ($test_files, $lib_path) = _built_test_sets($test_sets);
    
    my $harness = TAP::Harness->new({
        verbosity => $verbosity || 0,
        lib       => $lib_path,
    });
    
    my ($output, $errors) = capture {
        $harness->runtests(@$test_files);
    };

    return {
        'output' => $output,
        'errors' => $errors,
    }; 
        
}

sub _built_test_sets{
    my $test_sets = shift;
    
    my $tests = _get_tests();
    
    my @tests;
    my %lib_paths;
     
    foreach my $set (@$test_sets){
        if ($tests->{$set}){
            # Add tests
            push @tests, @{$tests->{$set}->{'tests'}};
            
            # Add the lib paths
            foreach my $path (@{$tests->{$set}->{'lib_paths'}}){
               $lib_paths{$path} = 1;
            }
        }
    }
    
    my @unique_lib_paths = keys %lib_paths;
    
    return \@tests, \@unique_lib_paths;

};    
    
sub _get_tests{
    my %tests = (
        'Courtside' => {
            'description' => 'Courtside tests',
            'tests' => [
                ['../courtside/courtside.cgi.t', 'Courtside cgi tests'],
                ['../courtside/CourtSide.pm.t',  'Courtside login tests'],
            ],
            'lib_paths' => ['../courtside/'],
        },
        'Programs' => {
            'description' => 'Program tests',
            'tests' => [
                ['../01_programs_obj.pl.t', 'Program Object tests'],
            ],
            'lib_paths' => ['../', '../comp/'],
        },
    );
    
    return \%tests;
}

