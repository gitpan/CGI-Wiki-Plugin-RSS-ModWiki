package CGI::Wiki::Plugin::RSS::ModWiki;

use strict;

use vars qw( $VERSION );
$VERSION = '0.06';

use XML::RSS;
use Time::Piece;
use URI::Escape;
use Carp qw( croak );

=head1 NAME

  CGI::Wiki::Plugin::RSS::ModWiki - A CGI::Wiki plugin to output RecentChanges RSS.

=head1 DESCRIPTION

This is an alternative access to the recent changes of a CGI::Wiki
wiki. It outputs RSS as described by the ModWiki proposal at
L<http://www.usemod.com/cgi-bin/mb.pl?ModWiki>

=head1 SYNOPSIS

  use CGI::Wiki;
  use CGI::Wiki::Plugin::RSS::ModWiki;

  my $wiki = CGI::Wiki->new( ... );  # See perldoc CGI::Wiki

  # Set up the RSS feeder with the mandatory arguments - see
  # C<new> below for more, optional, arguments.
  my $rss = CGI::Wiki::Plugin::RSS::ModWiki->new(
      wiki                 => $wiki,
      site_name            => "My Wiki",
      make_node_url        => sub {
                                    my ($node_name, $version) = @_;
                                    return "http://example.com/?id="
                                    . uri_escape($node_name)
                                    . ";version=" . uri_escape($version);
                                  },
      recent_changes_link  => "http://example.com/?RecentChanges",
  );

  print "Content-type: application/xml\n\n";
  print $rss->recent_changes;

=head1 METHODS

=over 4

=item B<new>

  my $rss = CGI::Wiki::Plugin::RSS::ModWiki->new(
      wiki                 => $wiki,
      site_name            => "My Wiki",
      make_node_url        => sub {
                                my ($node_name, $version) = @_;
                                return "http://example.com/?id="
                                . uri_escape($node_name)
                                . ";version=" . uri_escape($version);
                                  },
      recent_changes_link  => "http://example.com/?RecentChanges",
  # Those above were mandatory, those below are optional.
      site_description     => "My wiki about my stuff",
      interwiki_identifier => "KakesWiki",
      make_diff_url        => sub {
                                   my $node_name = shift;
                                   return "http://example.com/?diff="
                                          . uri_escape($node_name)
                                  },
      make_history_url     => sub {
                                   my $node_name = shift;
                                   return "http://example.com/?hist="
                                          . uri_escape($node_name)
                                  },
  );

C<wiki> must be a L<CGI::Wiki> object. C<make_node_url>, and
C<make_diff_url> and C<make_history_url>, if supplied, must be coderefs.

B<NOTE:> If you try to put ampersands (C<&>) in your URLs then
L<XML::RSS> will escape them to C<&amp;>, so use semicolons (C<;>) to
separate any CGI parameter pairs instead.

The mandatory arguments are:

=over 4

=item * wiki

=item * site_name

=item * make_node_url

=item * recent_changes_link

=back

=cut

sub new {
    my ($class, @args) = @_;
    my $self = {};
    bless $self, $class;
    return $self->_init(@args);
}

sub _init {
    my ($self, %args) = @_;
    my $wiki = $args{wiki};
    unless ( $wiki && UNIVERSAL::isa( $wiki, "CGI::Wiki" ) ) {
        croak "No CGI::Wiki object supplied.";
      }
    $self->{wiki} = $wiki;
    # Mandatory arguments.
    foreach my $arg ( qw( site_name make_node_url recent_changes_link ) ) {
        croak "No $arg supplied" unless $args{$arg};
        $self->{$arg} = $args{$arg};
    }
    # Optional arguments.
    foreach my $arg ( qw( site_description interwiki_identifier
			  make_diff_url make_history_url ) ) {
        $self->{$arg} = $args{$arg} || "";
    }
    return $self;
}

=item B<recent_changes>

  $wiki->write_node( "About This Wiki",
		     "blah blah blah content",
		     $checksum,
		     {
                       comment  => "Stub page, please update!",
		       username => "Kake"
                     }
  );

  print "Content-type: application/xml\n\n";
  print $rss->recent_changes;

  # Or get something other than the default of the latest 15 changes.
  print $rss->recent_changes( items => 50 );
  print $rss->recent_changes( days => 7 );

  # Or ignore minor changes.
  print $rss->recent_changes( ignore_minor_changes => 1 );

  # Personalise your feed further - consider only changes
  # made by Kake to pages about pubs.
  print $rss->recent_changes(
                       filter_on_metadata => {
                                               username => "Kake",
                                               category => "Pubs",
                                             },
                            );

If using C<filter_on_metadata> note that only changes satisfying
I<all> criteria will be returned.

B<Note:> Many of the fields emitted by the RSS generator are taken
from the node metadata. The form of this metadata is I<not> mandated
by CGI::Wiki. Your wiki application should make sure to store some or
all of the following metadata when calling C<write_node>:

=over 4

=item B<comment> - a brief comment summarising the edit that has just been made; will be used in the RDF description for this item.  Defaults to the empty string.

=item B<username> - an identifier for the person who made the edit; will be used as the Dublin Core contributor for this item, and also in the RDF description.  Defaults to the empty string.

=item B<host> - the hostname or IP address of the computer used to make the edit; if no username is supplied then this will be used as the Dublin Core contributor for this item.  Defaults to the empty string.

=item B<major_change> - true if the edit was a major edit and false if it was a minor edit; used for the importance of the item.  Defaults to true (ie if C<major_change> was not defined or was explicitly stored as C<undef>).

=back

=cut

sub recent_changes {
    my ($self, %args) = @_;

    my $rss = new XML::RSS (version => '1.0');

    $rss->add_module(
        prefix => 'wiki',
        uri    => 'http://purl.org/rss/1.0/modules/wiki/'
    );

    my $time = localtime;
    my $timestamp = $time->strftime( "%Y-%m-%dT%H:%M:%S" );

    $rss->channel(
        title         => $self->{site_name},
        link          => $self->{recent_changes_link},
        description   => $self->{site_description},
        dc => {
            date        => $timestamp
        },
        wiki => {
            interwiki   => $self->{interwiki_identifier}
        }
    );

    # If we're not passed any parameters to limit the items returned,
    # default to 15, which is apparently the modwiki standard.
    my $wiki = $self->{wiki};
    my %criteria = ( ignore_case => 1 );
    if ( $args{days} ) {
        $criteria{days} = $args{days};
    } else {
        $criteria{last_n_changes} = $args{items} || 15;
    }
    if ( $args{ignore_minor_changes} ) {
        $criteria{metadata_wasnt} = { major_change => 0 };
    }
    if ( $args{filter_on_metadata} ) {
        $criteria{metadata_was} = $args{filter_on_metadata};
    }
    my @changes = $wiki->list_recent_changes( %criteria );
    foreach my $change (@changes) {
        my $node_name   = $change->{name};

        my $timestamp = $change->{last_modified};
	# Make a Time::Piece object.
        my $timestamp_fmt = $CGI::Wiki::Store::Database::timestamp_fmt;
#        my $timestamp_fmt = $wiki->{store}->timestamp_fmt;
	my $time = Time::Piece->strptime( $timestamp, $timestamp_fmt );
	$timestamp = $time->strftime( "%Y-%m-%dT%H:%M:%S" );

        my $author      = $change->{metadata}{username}[0]
	                    || $change->{metadata}{host}[0] || "";

        my $description = $change->{metadata}{comment}[0] || "";
        $description .= " [$author]" if $author;

        my $version = $change->{version};
        my $status = (1 == $version) ? 'new' : 'updated';
        my $major_change = $change->{metadata}{major_change}[0];
        $major_change = 1 unless defined $major_change;
        my $importance = $major_change ? 'major' : 'minor';

        my $url = $self->{make_node_url}->( $node_name, $version );

        my $diff_url = "";
        if ( $self->{make_diff_url} ) {
	    $diff_url = $self->{make_diff_url}->( $node_name );
	}

        my $history_url = "";
        if ( $self->{make_history_url} ) {
	    $history_url = $self->{make_history_url}->( $node_name );
	}

        $rss->add_item(
            title         => $node_name,
            link          => $url,
            description   => $description,
            dc => {
                date        => $timestamp,
                contributor => $author,
            },
            wiki => {
                status      => $status,
                importance  => $importance,
                diff        => $diff_url,
                version     => $version,
                history     => $history_url
            },
        );
    }

    return $rss->as_string;
}

=head1 SEE ALSO

=over 4

=item * L<CGI::Wiki>

=item * L<http://www.usemod.com/cgi-bin/mb.pl?ModWiki>

=back

=head1 AUTHOR

Kake Pugh (kake@earth.li).

=head1 COPYRIGHT

     Copyright (C) 2003-4 Kake Pugh.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 CREDITS

The people on #core on irc.rhizomatic.net gave encouragement and
useful advice.

I cribbed some of this code from
L<http://www.usemod.com/cgi-bin/wiki.pl?WikiPatches/XmlRss>

=cut


1;
