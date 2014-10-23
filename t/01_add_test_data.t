use strict;

use CGI::Wiki::TestConfig::Utilities;
use CGI::Wiki;

use Test::More tests => $CGI::Wiki::TestConfig::Utilities::num_stores;

# Add test data to the stores.
my %stores = CGI::Wiki::TestConfig::Utilities->stores;

my ($store_name, $store);
while ( ($store_name, $store) = each %stores ) {
    SKIP: {
      skip "$store_name storage backend not configured for testing", 1
          unless $store;

      print "#\n##### TEST CONFIG: Store: $store_name\n#\n";

      my $wiki = CGI::Wiki->new( store => $store );

      $wiki->write_node( "Old Node",
                         "We will write at least 15 nodes after this one" );

      my $slept = sleep(2);
      warn "Slept for less than a second, 'days=n' test may pass even if buggy"
        unless $slept >= 1;

      for my $i ( 1 .. 15 ) {
          $wiki->write_node( "Temp Node $i", "foo" );
      }

      $slept = sleep(2);
      warn "Slept for less than a second, test results may not be trustworthy"
        unless $slept >= 1;

      $wiki->write_node( "Test Node 1",
                         "Just a plain test",
			 undef,
			 { username => "Kake",
			   comment  => "new node",
			 }
		       );

      $slept = sleep(2);
      warn "Slept for less than a second, 'items=n' test may fail"
        unless $slept >= 1;

      $wiki->write_node( "Calthorpe Arms",
		         "CAMRA-approved pub near King's Cross",
		         undef,
		         { comment  => "Stub page, please update!",
		           username => "Kake",
			   postcode => "WC1X 8JR",
			   locale   => [ "Bloomsbury" ]
                         }
      );

      $wiki->write_node( "Test Node 2",
                         "Gosh, another test!",
                         undef,
                         { username => "nou",
                           comment  => "testy testy",
                         }
                       );

      pass "$store_name test backend primed with test data";
    }
}
