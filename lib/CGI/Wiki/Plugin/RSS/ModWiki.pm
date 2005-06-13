package CGI::Wiki::Plugin::RSS::ModWiki;

use strict;

use vars qw( $VERSION );
$VERSION = '0.07';

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

    my $wiki = $self->{wiki};

    # If we're not passed any parameters to limit the items returned,
    # default to 15, which is apparently the modwiki standard.

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

    my $rss_timestamp = $self->rss_timestamp(%args);

    my $rss = qq{<?xml version="1.0" encoding="UTF-8"?>

<rdf:RDF
 xmlns       = "http://purl.org/rss/1.0/"
 xmlns:dc    = "http://purl.org/dc/elements/1.1/"
 xmlns:wiki  = "http://purl.org/rss/1.0/modules/wiki/"
 xmlns:rdf   = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
 xmlns:rdfs  = "http://www.w3.org/2000/01/rdf-schema#"
>

<channel rdf:about="} . $self->{recent_changes_link}  . qq{">
<title>}              . $self->{site_name}            . qq{</title>
<link>}               . $self->{recent_changes_link}  . qq{</link>
<description>}        . $self->{site_description}     . qq{</description>
<dc:date>}            . $rss_timestamp                    . qq{</dc:date>
<wiki:interwiki>}     . $self->{interwiki_identifier} . qq{</wiki:interwiki>};

    my (@urls, @items);

    foreach my $change (@changes) {
        my $node_name   = $change->{name};

        my $timestamp = $change->{last_modified};
        # Make a Time::Piece object.
        my $timestamp_fmt = $CGI::Wiki::Store::Database::timestamp_fmt;

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

        push @urls, qq{    <rdf:li rdf:resource="$url" />\n};

        my $diff_url = "";
        if ( $self->{make_diff_url} ) {
	        $diff_url = $self->{make_diff_url}->( $node_name );
	      }

        my $history_url = "";
        if ( $self->{make_history_url} ) {
          $history_url = $self->{make_history_url}->( $node_name );
        }

        my $node_url = $self->{make_node_url}->( $node_name );

        my $rdf_url = $node_url;
        $rdf_url =~ s/\?/\?id=/;
        $rdf_url .= ';format=rdf';
        
        push @items, qq{
<item rdf:about="$url">
  <title>$node_name</title>
  <link>$url</link>
  <description>$description</description>
  <dc:date>$timestamp</dc:date>
  <dc:contributor>$author</dc:contributor>
  <wiki:status>$status</wiki:status>
  <wiki:importance>$importance</wiki:importance>
  <wiki:diff>$diff_url</wiki:diff>
  <wiki:version>$version</wiki:version>
  <wiki:history>$history_url</wiki:history>
  <rdfs:seeAlso rdf:resource="$rdf_url" />
</item>
};
    }
    
    $rss .= qq{
<items>
  <rdf:Seq>
} . join('', @urls) . qq{  </rdf:Seq>
</items>
</channel>
} . join('', @items) . "\n</rdf:RDF>\n";
 
    return $rss;   
}

=item B<rss_timestamp>

  print $rss->rss_timestamp();

Returns the timestamp of the feed in POSIX::strftime style ("Tue, 29 Feb 2000 
12:34:56 GMT"), which is equivalent to the timestamp of the most recent item 
in the feed. Takes the same arguments as recent_changes(). You will most likely
need this to print a Last-Modified HTTP header so user-agents can determine
whether they need to reload the feed or not.
  
=cut

sub rss_timestamp {
  my ($self, %args) = @_;
  
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

  my @changes = $self->{wiki}->list_recent_changes( %criteria );

  my $last_change = $changes[0]->{last_modified};
  my $timestamp_fmt = $CGI::Wiki::Store::Database::timestamp_fmt;
  my $time = Time::Piece->strptime( $last_change, $timestamp_fmt );
  
  return $time->strftime;
}

=head1 SEE ALSO

=over 4

=item * L<CGI::Wiki>

=item * L<http://www.usemod.com/cgi-bin/mb.pl?ModWiki>

=back

=head1 MAINTAINER

Earle Martin <EMARTIN@cpan.org>. Originally by Kake Pugh <kake@earth.li>.

=head1 COPYRIGHT AND LICENSE

Copyright 2003-4 Kake Pugh. Subsequent modifications copyright 2005 
Earle Martin.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 CREDITS

The people on #swig on irc.freenode.net gave encouragement and
useful advice.

=cut


1;
