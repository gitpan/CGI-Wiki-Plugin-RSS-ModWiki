use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => "CGI::Wiki::Plugin::RSS::ModWiki",
    VERSION_FROM => "lib/CGI/Wiki/Plugin/RSS/ModWiki.pm",
	      PREREQ_PM => { CGI::Wiki => 0.59, # for metadata filtering
			     Test::More => 0,
			     XML::RSS => 0,
			     Time::Piece => '1.08', # so strptime doesn't warn
			     URI::Escape => 0 # for testing
                           }
);
