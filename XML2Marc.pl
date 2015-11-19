#!/usr/bin/perl

# ------------------------------------------------------------------------------

# This script takes the XML output of Heritage Library System ( http://www.isoxford.com/ )
# and generates a MRC file that can be imported into Koha ( http://koha-community.org/ )

# ------------------------------------------------------------------------------

#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    any later version.
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#    See <http://www.gnu.org/licenses/> for the copy of the licence.

# ------------------------------------------------------------------------------

use strict;
use warnings;
use Switch;
use IO qw(Handle File);
use Data::Dumper;
use Storable;

use XML::Simple;	# http://search.cpan.org/~grantm/XML-Simple-2.18/lib/XML/Simple.pm
use MARC::Record;	# http://search.cpan.org/dist/MARC-Record/ by http://wiki.koha-community.org/wiki/Galen_Charlton

# Translate the room number into human compatible version
sub room_translation {
	my ( $room )=  @_;
	switch ( $room ) {
		case ""			{	$room = "ML"; }
		case "M"		{	$room = "ML"; }
		case "MAIN"		{	$room = "ML"; }
		case "LIBRARY"		{	$room = "ML"; }
		case "DC"		{	$room = "DP"; }
		case "MACCANA"		{	$room = "MacC"; }
		case "PROCESSING"	{	$room = "PRO"; }
		case "REF ONLY"		{	$room = "REF"; }
		case "SPECIAL-COLLECTION"{	$room = "SC"; }
	}
	return $room;
}

# Translate the medium into item type
sub medium_translation {
	my ( $medium )=  @_;
	switch ( $medium ) {
		case "MakesWithTheNopes"			{	$medium = "BK"; }
		#case "Text"			{	$medium = "BK"; }
		case "Cartographic"		{	$medium = "MP"; }
		#case "Pamphlet"			{	$medium = "PA"; }
		#case "Microfilm/Microfiche"	{	$medium = "MI"; }
		#case "Compact Disk"		{	$medium = "CD"; }
		#case "Text &amp; Audio Cassette"	{	$medium = "BKK7"; }
		#case "Text with CD"		{	$medium = "BKCD"; }
		#case "Text with CDs"		{	$medium = "BKCD"; }
		#case "Text with DVD"		{	$medium = "BKDVD"; }
		#case "DVD"			{	$medium = "VM"; }
		#case "Video recording"		{	$medium = "VM"; }
		#case "Audio Cassette"		{	$medium = "K7"; }
		#case "Manuscript"		{	$medium = "MU"; }
		#case "PDF (document image)"	{	$medium = "E-BK"; }
		#case "On Order"			{	$medium = "PRINT"; }
		#else				{	$medium = "PRINT"; }
		else				{	$medium = "UNKNOWN"; }
	}
	return $medium;
}

# Translate heritage notes into marc format
sub notes_translation {
	my ( $notes, $record )=  @_;
	my $notescsvx;
	# Todo public note 952 z
	# Todo non public note 952 x
	foreach ( split(/\|\|/, $notes) ) {
		if ( $_ =~ "(SBN)" ) {
			$_ =~ s/\(SBN\) //g;
			$notescsvx = MARC::Field->new('020',1,'',a => $_);
		} elsif ( $_ =~ "(TIT)" ) {
			$_ =~ s/\(TIT\) //g;
			$notescsvx = MARC::Field->new('246',1,'',a => $_);
		} elsif ( $_ =~ "(OWN)" ) { # TODO Find the correct MARC field
			$_ =~ s/\(OWN\) //g;
			$notescsvx = MARC::Field->new('500',1,'',a => $_);
		} elsif ( $_ =~ "(BIB)" ) {
			$_ =~ s/\(BIB\) //g;
			$notescsvx = MARC::Field->new('504',1,'',a => $_);
		} elsif ( $_ =~ "(BIBI)" ) {
			$_ =~ s/\(BIBI\) //g;
			$notescsvx = MARC::Field->new('504',1,'',a => $_);
		} elsif ( $_ =~ "(LAN)" ) {
			$_ =~ s/\(LAN\) //g;
			$notescsvx = MARC::Field->new('546',1,'',a => $_);
		} elsif ( $_ =~ "(BND)" ) {
			$_ =~ s/\(BND\) //g;
			$notescsvx = MARC::Field->new('563',1,'',a => $_);
		} elsif ( $_ =~ "(CON)" ) {
			$_ =~ s/\(CON\) //g;
			$notescsvx = MARC::Field->new('505',1,'',a => $_);
		} elsif ( $_ =~ "(RES)" ) {
			$_ =~ s/\(RES\) //g;
			$notescsvx = MARC::Field->new('505',1,'',r => $_);
		} elsif ( $_ =~ "(SUM)" ) {
			$_ =~ s/\(SUM\) //g;
			$notescsvx = MARC::Field->new('520',1,'',a => $_);
		} elsif ( $_ =~ "(WIT)" ) {
			$_ =~ s/\(WIT\) //g;
			$notescsvx = MARC::Field->new('501',1,'',a => $_);
		} else {
			$_ =~ s/\(DON\) /Donation /g;
			$_ =~ s/\(OLD\) /Old accession number /g;
			$_ =~ s/\(CON\) /Contents /g;
			$_ =~ s/\(PUB\) /Publication\/Distribution /g;
			$_ =~ s/\(PHY\) /Physical /g;
			$_ =~ s/\(IND\) /Index /g;
			$_ =~ s/\(BIBI\) /Bibliography and index note /g;
			$_ =~ s/\(HOL\) /Holdings /g;
			$_ =~ s/\(CIP\) /Publication date /g;
			$_ =~ s/\(HIS\) /History and edition /g;
			$_ =~ s/\(LOC\) /Locution note/g;
			$_ =~ s/\(SER\) /Series /g;
			$_ =~ s/\(EDN\) /Edition /g;
			$_ =~ s/\(DES\) /Description /g;
			$_ =~ s/\(SUM\) /Subscriptions (Serials) /g;
			$_ =~ s/\(RES\) /Responsability statement /g;
			$_ =~ s/\(DIS\) /Dissertation /g;
			$_ =~ s/\(MPT\) /Volume part /g;
			$_ =~ s/\(USE\) /Mode of use note /g;
			$_ =~ s/\(NO\) /Notes /g;
			$_ =~ s/\(BIBLIO\) //g;
			$_ =~ s/\(INDX\) /Indexes /g;
			$_ =~ s/\(ACC\) /Accompanying material /g;
			$_ =~ s/\(REV\) /Review /g;
			$_ =~ s/\(NAT\) /Nature /g;
			$_ =~ s/\(VER\) /Version available /g;
			$_ =~ s/\(GEN\) //g;
			$notescsvx = MARC::Field->new('500',1,'',a => $_);
		}
		$record->append_fields($notescsvx);
	}
}

# the file to parse
my $xmlfile = shift @ARGV;

# default settings
my $location = "SCS";
my $accprefix = "";

my $skip = 0;


# Read the XML file
my $booklist;
if ( ! -e $xmlfile . '.dump' ) {
	$booklist = XMLin( $xmlfile, SuppressEmpty => 1 );
	print ref( $booklist );
	store $booklist, $xmlfile . '.dump';
} else {
	$booklist = retrieve $xmlfile . '.dump';
}


# Initialize the output
my $fh;
open($fh, '>:utf8', $xmlfile . '.mrc') or die $!;

# The Main Loop
my $record;
my $documenttype = "";
my $documentcount = 0;
foreach my $book (@{$booklist->{record}}) {

	# print $book->{ID} . "\n";
	$record = MARC::Record->new();

	# add the leader to the record. optional.
	$record->leader('00903pam  2200265 a 4500');

	# specify the encoding (accents and various chars)
	$record->encoding( 'UTF-8' );

	if ( exists $book->{medium} ) {
		$documenttype = medium_translation( $book->{medium} );
	} else {
		print "Error: Medium not found!", $book->{ID}, "\n";
		next;
	}

	if ( $documenttype eq "UNKNOWN" ) {
		next;
	}
	if ( $documenttype eq "PRINT" ) {
		print Dumper( $book );
		next;
	}



	if ( exists $book->{accloc} ) {
		if( ref($book->{accloc}) ) {
			$skip = 0;
			foreach ( @{$book->{accloc}} ) {
				if ( $_ eq 'R20' ) {
					$skip = 1;	
				}
			}
			if ( $skip == 1 ) {
				next;
			}
		} else{
			if ( $book->{accloc} eq 'R20' ) {
				next;
			}
		}
	}
	
	# stdno
	if ( exists $book->{stdno} ) {
		my $stdno;
		foreach ( $book->{stdno} ) {
			$stdno = MARC::Field->new(
				'024',1,'',
					a => $_
			);
		}
		$record->append_fields($stdno);
	}

	# isbn
	if ( exists $book->{isbn} ) {
		my $isbn = MARC::Field->new(
			'020',1,'',
				a => $book->{isbn}
		);
		$record->append_fields($isbn);
	}

	# title
	if ( exists $book->{title} ) {
		# TODO: split title as follow:
		# title : subtitle / garbage
		my $title = MARC::Field->new(
			'245',1,'',
				a => $book->{title}
		);
		$record->append_fields($title);
	}

	# edition
	if ( exists $book->{edition} ) {
		my $edition = MARC::Field->new(
			'250',1,'',
				a => $book->{edition}
		);
		$record->append_fields($edition);
	}

	# persauthorfull
	if ( exists $book->{persauthorfull} ) {
		my $firstauthor = 1; # In case of several authors
		my $persauthorfull;

		# if this is a reference, it's a list
		if( ref($book->{persauthorfull}) ) {
			foreach ( @{$book->{persauthorfull}} ) {
				if ( $firstauthor == 1 ) {
					$persauthorfull = MARC::Field->new(
						'100',1,'',
							a => $_ #book->{persauthorfull}
					);
					$firstauthor = 0;
				} else {
					$persauthorfull = MARC::Field->new(
						'700',1,'',
							a => $_
					);
				}

				$record->append_fields($persauthorfull);
			}
		} else { # it's only one author
			$persauthorfull = MARC::Field->new(
				'100',1,'',
				a => $book->{persauthorfull}
			);
			$firstauthor = 0;
			$record->append_fields($persauthorfull);
		}
	}

	# author
	if ( exists $book->{author} ) {
		my $firstauthor = 1;
		my $author;

		# if this is a reference, it's a list
		if( ref($book->{author}) ) {
			foreach ( @{$book->{author}} ) {
				if ( $firstauthor == 1 ) {
					$author = MARC::Field->new(
						'100',1,'',
							a => $_ #book->{author}
					);
					$firstauthor = 0;
				} else {
					$author = MARC::Field->new(
						'700',1,'',
							a => $_
					);
				}

				$record->append_fields($author);
			}
		} else {
			$author = MARC::Field->new(
				'100',1,'',
				a => $book->{author}
			);
			$firstauthor = 0;
			$record->append_fields($author);
		}
	}

	# corpauthor
	if ( exists $book->{corpauthor} ) {
		my $corpauthor;
		if( ref($book->{corpauthor}) ) {
			foreach ( @{$book->{corpauthor}} ) {
				$corpauthor = MARC::Field->new(
					'710',2,'',
						a => $_
				);
				$record->append_fields($corpauthor);
			}
		} else {
			$corpauthor = MARC::Field->new(
				'710',2,'',
				a => $book->{corpauthor}
			);
			$record->append_fields($corpauthor);
		}
	}

	# Get the location based on the class in the case of ML, REF and SC
	if (( ! exists $book->{accloc} ) &&
	    ( exists $book->{class} ) ) {
	    	if ( $book->{class} =~ /^[0-9]/ ) {
			$book->{accloc} = 'ML';
		}
		if ( $book->{class} =~ /^U [0-9]/ ) {
			$book->{accloc} = 'REF';
		}
		if ( $book->{class} =~ /^SC [0-9]/ ) {
			$book->{accloc} = 'SC';
		}
	}

	# item
	if (( exists $book->{accloc} ) &&
	    ( exists $book->{class} ) &&
	    ( exists $book->{accno} ) ) {
		if( ref($book->{accloc}) ) {
			if ( ! ref($book->{class} ) ) {
				print "Warning: ". $book->{ID}. " Class is missing, using " . $book->{class} . " instead\n";
				my $class = $book->{class};
				$book->{class} = qw();
				foreach ( @{$book->{accno}} ) {
					push(@{$book->{class}}, $class);
				}
			}

			my $i = 0;
			foreach ( @{$book->{accloc}} ) {
				my $room = room_translation( $book->{accloc}->[$i] );
				my $item = MARC::Field->new(
					'952',1,'',
						#8 => $documenttype,
						a => "SCS",
						b => $location,
						c => $room,
						o => $book->{class}->[ $i ],
						p => $accprefix . $book->{accno}->[ $i ],
						y => $documenttype
				);
				$record->append_fields($item);
				$i ++;
			}
		} else {
			my $room = room_translation( $book->{accloc} );
			my $item = MARC::Field->new(
				'952',1,'',
					#8 => $documenttype,
					a => "SCS",
					b => $location,
					c => $room,
					o => $book->{class},
					p => $accprefix . $book->{accno},
					y => $documenttype
			);
			$record->append_fields($item);
		}
	} else {
		print "Warning: Cannot create item(s) for record ". $book->{ID};
		if ( ! exists($book->{accno} ) ) {
				print " [ AccNo is missing ]";
		} else {
				print " [ AccNo " . $book->{accno} . " ]";
		}
		if ( ! exists($book->{accloc} ) ) {
				print " [ AccLoc is missing ]";
		} else {
				print " [ AccLoc " . $book->{accloc} . " ]";
		}
		if ( ! exists($book->{class} ) ) {
				print " [ Class is missing ]";
		} else {
				print " [ Class " . $book->{class} . " ]";
		}
		print "\n";
	}

	# Create field 260 with a dummy information
	my $r260 = MARC::Field->new( '260',1,'', z => "dummy" );

	# add place
	if ( exists $book->{place} ) {
		if( ref($book->{place}) ) {
			foreach ( @{$book->{place}} ) {
				$r260->add_subfields( a => $_ );
			}
		} else {
			$r260->add_subfields( a => $book->{place} );
		}
	}

	# add publisher
	if ( exists $book->{publisher} ) {
		if( ref($book->{publisher}) ) {
			foreach ( @{$book->{publisher}} ) {
				$r260->add_subfields( b => $_ );
			}
		} else {
			$r260->add_subfields( b => $book->{publisher} );
		}
	}
	# add year
	if ( exists $book->{year} ) {
		if( ref($book->{year}) ) {
			foreach ( @{$book->{year}} ) {
				$r260->add_subfields( c => $_ );
			}
		} else {
			$r260->add_subfields( c => $book->{year} );
		}
	}

	# Remove the dummy subfields
	$r260->delete_subfield( code => 'z' );
	my @sr260 = $r260->subfields();

	# If more than 0 fields, we add it to the record
	if ( $#sr260 > 0 ) {
		$record->append_fields($r260);
	}

	# collation
	if ( exists $book->{collation} ) {
		my $collation;
		if ( $book->{collation} =~ /(.*p\..*):(.*(ill|fac|port|biblio|tables|diag).*);(.*(cm|to|vo).*)/ ) {
			my $a = $1;
			my $b = $2;
			my $c = $3;
			$collation = MARC::Field->new( 	'300',1,'', a => $a, b => $b, c => $c );
		} elsif ( $book->{collation} =~ /(.*p\..*);(.*ill.*):(.*(cm|to|vo).*)/ ) {
			my $a = $1;
			my $b = $2;
			my $c = $3;
			$collation = MARC::Field->new( 	'300',1,'', a => $a, b => $b, c => $c );
		} elsif ( $book->{collation} =~ /(.*p\..*);(.*(cm|to|vo).*)/ ) {
			my $a = $1;
			my $c = $2;
			$collation = MARC::Field->new( 	'300',1,'', a => $a, c => $c );
		} else {
			$collation = MARC::Field->new(	'300',1,'', a => $book->{collation} );
		}
		$record->append_fields($collation);
	}

	# subjects
	if ( exists $book->{subjects} ) {
		my $subjects;
		if( ref($book->{subjects}) ) {
			foreach ( @{$book->{subjects}} ) {
				$subjects = MARC::Field->new(
					'650',1,'',
						a => $_ #book->{subjects}
				);
				$record->append_fields($subjects);
			}
		} else {
			$subjects = MARC::Field->new(
				'650',1,'',
				a => $book->{subjects}
			);
			$record->append_fields($subjects);
		}
	}

	# series
	my $series = "";
	if ( exists $book->{series} ) {
		$series = $book->{series};
	}

	# seriesno
	my $seriesno = "";
	if ( exists $book->{seriesno} ) {
		$seriesno = $book->{seriesno};
	}

	# r830
	my $r830 = MARC::Field->new(
		'830',1,'',
			a => $series,
			v => $seriesno
	);
	$record->append_fields($r830);

	# lng
	my $lng = "110714s||||||||xx||||||||||||||||||eng|d";
	if ( exists $book->{lng} ) {
		substr($lng,35,3) = $book->{lng};
	}
	# r008
	my $r008 = MARC::Field->new(
		'008',lc($lng)
	);
	$record->append_fields($r008);

	# notescsvx
	if ( exists $book->{notescsvx} ) {
		if( ref($book->{notescsvx}) ) {
			foreach ( @{$book->{notescsvx}} ) {
				notes_translation( $_, $record )
			}
		} else {
			notes_translation( $book->{notescsvx}, $record )
		}
	}


	print $fh $record->as_usmarc();
	$documentcount ++;

	# Not freeing the memory, but it doesn't matter =-D
}

print $documentcount, "\n";

close($fh);

