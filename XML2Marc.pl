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
# If medium = MI and room = LD  then room = P/O
sub room_translation {
	my ( $room, $medium )=  @_;
	switch ( $room ) {
		case ""			{	$room = "ML"; }
		case "M"		{	$room = "ML"; }
		case "MAIN"		{	$room = "ML"; }
		case "LIBRARY"		{	$room = "ML"; }
		case "DC"		{	$room = "DP"; }
		case "MACCANA"		{	$room = "MacC"; }
		case "REF ONLY"		{	$room = "REF"; }
		case "SPECIAL-COLLECTION"{	$room = "SC"; }
		case "P/O"		{}
		case "CP"		{}
		case "GQ"		{}
		case "MAP"		{}
		case "ML"		{}
		case "DP"		{}
		case "LB"		{}
		case "LP"		{}
		case "LD"		{	$room = "P/O" if ( $medium eq "MI" ); }
		case "RBC"		{}
		case "NB"		{}
		case "OMC"		{}
		case "REF"		{	$room = "SKIP"; }
		case "PROCESSING"	{	$room = "SKIP"; }
		#case "R20"		{	$room = "SKIP"; }
		case "R20"		{}
		else			{	print "Location unknown: ", $room, "\n";
						$room = "UNKNOWN"; }
	}
	return $room;
}

# Translate the medium into item type
sub medium_translation {
	my ( $medium )=  @_;
	switch ( $medium ) {
		case "Text"			{	$medium = "BK"; }
		case "Cartographic"		{	$medium = "MP"; }
		case "Pamphlet"			{	$medium = "PA"; }
		case "Microfilm/Microfiche"	{	$medium = "MI"; }
		case "Compact Disk"		{	$medium = "CD"; }
		case "Text &amp; Audio Cassette"	{	$medium = "BKK7"; }
		case "Text & Audio Cassette"	{	$medium = "BKK7"; }
		case "Text with CD"		{	$medium = "BKCD"; }
		case "Text with CDs"		{	$medium = "BKCD"; }
		case "Text with DVD"		{	$medium = "BKDVD"; }
		case "DVD"			{	$medium = "VM"; }
		case "Video recording"		{	$medium = "VM"; }
		case "Audio Cassette"		{	$medium = "K7"; }
		case "Manuscript"		{	$medium = "MU"; }
		case "PDF (document image)"	{	$medium = "E-BK"; }
		case "E-book"			{	$medium = "E-BK"; }
		case "Journal"			{	$medium = "J"; }
		case "New Book"			{	$medium = "New Book"; }
		#case "On Order"			{	$medium = "PRINT"; }
		#else				{	$medium = "PRINT"; }
		else				{	#print "Medium unknown: ", $medium, "\n";
							$medium = "UNKNOWN"; }
	}
	return $medium;
}

# Class 81x.xx.. -->  981.6xxx..
sub class_translation {
	my ( $class )=  @_;
	if ( $class =~ /^81([0-9]*\.[0-9]*)/ ) {
		#print( "Reclassifying $class\t\t-->\t" );
		$class =~ s/^81([0-9]*)\.([0-9]*)/891.6$1$2/g;
		#print( $class . "\n" );
	} elsif ( $class =~ / 81([0-9]*\.[0-9]*)/ ) {
		#print( "Reclassifying $class\t\t-->\t" );
		$class =~ s/ 81([0-9]*)\.([0-9]*)/ 891.6$1$2/g;
		#print( $class . "\n" );
	}
	return $class;
}

# Status translation
sub status_translation {
	my ( $status )=  @_;
	my $lost = 0;
	my $notforloan = 0;
	switch ( $status ) {
		case ""			{	$status = "Available"; }
		case "Available"	{	$status = "Available"; }
		case "Retro/Available"	{	$status = "Available"; }
		case "On Loan"		{	$status = "Available"; }
		case "On Order"		{	$status = "Available"; }
		case "Held"		{	$status = "NotForLoan"; $notforloan = 1; }
		case "Missing"		{	$status = "Missing"; $lost = "4"; }
		#5     <accstatus>Binding</accstatus>
		else				{	print "Warning: Status unknown ", $status, "\n";
							$status = "UNKNOWN"; }
	}
	return ($status, $notforloan, $lost);
}

# Loan type translation
sub loantype_translation {
	my ( $loantype )=  @_;
	switch ( $loantype ) {
		case ""				{	$loantype = 3; }
		case "MAIN LIBRARY"		{	$loantype = 3; }
		case "MAP CABINET"		{	$loantype = 5; }
		case "One week loan"		{	$loantype = 4; }
		case "PAMPHLETS/OFFPRINTS"	{	$loantype = 3; }
		case "Reference only"		{	$loantype = 5; }
		case "Restricted Access"	{	$loantype = 5; }
		case "SPECIAL COLLECTION"	{	$loantype = 4; }
		case "Short loan"		{	$loantype = 4; }
		case "Standard loan"		{	$loantype = 3; }
		else				{	print "Warning: Loan type unknown ", $loantype, "\n";
							$loantype = 0; }
	}
	return $loantype;
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
		} elsif ( $_ =~ "(OWN)" ) {
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
			$_ =~ s/\(LOC\) /Location note /g;
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
	store $booklist, $xmlfile . '.dump';
} else {
	$booklist = retrieve $xmlfile . '.dump';
}

# Read XML associated file
my $assoclist = XMLin( "assoc.xml", SuppressEmpty => 1 );

# Initialize the output
my $fh;
open($fh, '>:utf8', $xmlfile . '.mrc') or die $!;

# The Main Loop
my $record;
my $documenttype = "";
my $documentcount = 0;
my $documentcountitems = 0;
my $documenttypeunknown = 0;
my $documentskip = 0;
my $documentprocessing = 0;
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
		$documenttypeunknown ++;
		next;
	}
	if ( $documenttype eq "PRINT" ) {
		print Dumper( $book );
		next;
	}


	# Special case for new books
	if ( $documenttype eq "New Book" ) {
		$book->{accloc} = "NB";
		$documenttype = "BK";
		print( "Info: New Book ". $book->{ID} . "\n" );
	}


	if ( exists $book->{accloc} ) {
		if( ref($book->{accloc}) ) {
			$skip = 0;
			foreach ( @{$book->{accloc}} ) {
				if ( room_translation( $_, $documenttype ) eq 'SKIP' ) {
					$skip = 1;	
				}
			}
			if ( $skip == 1 ) {
				$documentskip ++;
				next;
			}
		} else{
			if ( room_translation( $book->{accloc}, $documenttype ) eq 'SKIP' ) {
				$documentskip ++;
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

	if ( $documenttype ne "J" ) {
		# isbn
		if ( exists $book->{isbn} ) {
			my $isbn = MARC::Field->new(
				'020',1,'',
					a => $book->{isbn}
			);
			$record->append_fields($isbn);
		}
	} else {
		# issn
		if ( exists $book->{issn} ) {
			my $issn = MARC::Field->new(
				'022',1,'',
					a => $book->{issn}
			);
			$record->append_fields($issn);
		}
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

	if ( $documenttype eq "J" ) {
		# prevtitle
		if ( exists $book->{prevtitle} ) {
			my $prevtitle = MARC::Field->new(
				'780',1,'',
					t => $book->{prevtitle}
			);
			$record->append_fields($prevtitle);
		}

		# nexttitle
		if ( exists $book->{nexttitle} ) {
			my $nexttitle = MARC::Field->new(
				'785',1,'',
					t => $book->{nexttitle}
			);
			$record->append_fields($nexttitle);
		}
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

	if ( $documenttype eq "J" ) {
		# issuingbody
		if ( exists $book->{issuingbody} ) {
			my $issuingbody;
			if( ref($book->{issuingbody}) ) {
				foreach ( @{$book->{issuingbody}} ) {
					$issuingbody = MARC::Field->new(
						'710',2,'',
							a => $_
					);
					$record->append_fields($issuingbody);
				}
			} else {
				$issuingbody = MARC::Field->new(
					'710',2,'',
					a => $book->{issuingbody}
				);
				$record->append_fields($issuingbody);
			}
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

	if ( $documenttype ne "J" ) {
		# Fix Room20 missing class
		if (( exists $book->{accloc} ) &&
		    ( ! exists $book->{class} ) &&
		    ( exists $book->{accno} ) ) {
			if( ref($book->{accloc}) ) {
				my $i = 0;
				foreach ( @{$book->{accloc}} ) {
					my $room = room_translation( $book->{accloc}->[$i], $documenttype );
					if ( $room eq "R20" ) {
						$book->{class} = "R20";
					}
					$i ++;
				}
			} else {
				my $room = room_translation( $book->{accloc}, $documenttype );
				if ( $room eq "R20" ) {
					$book->{class} = "R20";
				}
			}
		}

		# item
		if (( exists $book->{accloc} ) &&
		    ( exists $book->{class} ) &&
		    ( exists $book->{accno} ) ) {
			if( ref($book->{accno}) ) {

				# If some items have no location, we need to report it
				if ( ! ref($book->{accloc} ) ) {
					print "Warning: ". $book->{ID}. " Location is missing for one item, using " . $book->{accloc} . " instead,  items are @{$book->{accno}}\n";
					my $accloc = $book->{accloc};
					$book->{accloc} = qw();
					foreach ( @{$book->{accloc}} ) {
						push(@{$book->{accloc}}, $accloc);
					}
				}

				# If one class available, we apply to all items
				if ( ! ref($book->{class} ) ) {
					my $class = class_translation($book->{class});
					$book->{class} = qw();
					foreach ( @{$book->{accno}} ) {
						push(@{$book->{class}}, $class);
					}
				} else {
					my $i = 0;
					my $class = $book->{class};
					foreach ( @{$class} ) {
						$_ = class_translation( $_ );
					}
					$book->{class} = qw();
					foreach ( @{$book->{accno}} ) {
						push(@{$book->{class}}, "")
					}


					print "$book->{ID}\t [ ";
					foreach ( @{$class} ) {
						print	"$_ | "; 
					}
					print "]\n";


					# Give a class to each item
					$i = 0;
					foreach ( @{$book->{accno}} ) {
						my $room = room_translation( $book->{accloc}->[$i], $documenttype );

						switch ( $room ) {
							case "LD" {
									foreach ( @{$class} ) {
										if ( $_ =~ /de B*/ ) {
											$book->{class}->[$i] = $_; 
										}
										if ( $_ =~ /CD */ ) {
											$book->{class}->[$i] = $_; 
										}
										if ( $_ =~ /DVD */ ) {
											$book->{class}->[$i] = $_; 
										}
									}
								}
							case "MacC" {
									foreach ( @{$class} ) {
										if ( $_ =~ /[0-9]* \/ [A-Z]*/ ) {
											$book->{class}->[$i] = $_; 
										}
									}
								}
							case "CP" {
									foreach ( @{$class} ) {
										if ( $_ =~ /U [0-9\.]{3,10} */ ) {
											$book->{class}->[$i] = $_; 
										}
									}
								}
							case "REF" {
									foreach ( @{$class} ) {
										if ( $_ =~ /U [0-9\.]{3,10} */ ) {
											$book->{class}->[$i] = $_; 
										}
									}
								}
							case "SC" {
									foreach ( @{$class} ) {
										if ( $_ =~ /SC */ ) {
											$book->{class}->[$i] = $_; 
										}
									}
								}
							case "P/O" {
									foreach ( @{$class} ) {
										if ( $_ =~ /P\/ */ ) {
											$book->{class}->[$i] = $_; 
										}
									}
								}
							case "LB" {
									foreach ( @{$class} ) {
										if ( $_ =~ /LB */ ) {
											$book->{class}->[$i] = $_; 
										}
									}
								}
							case "R20" {
									$book->{class}->[$i] = "R20"; 
								}
							case "ML" {
									foreach ( @{$class} ) {
										if ( $_ =~ /^Ir [0-9\.]{3,10} */ ) {
											$book->{class}->[$i] = $_; 
										}
										if ( $_ =~ /^[0-9\.]{3,10} */ ) {
											$book->{class}->[$i] = $_; 
										}
									}
								}
							else { 
								print( "Warning: location ". $room . " needs to be defined\n"); 
								}
						}

						$i ++;
					}

					# Double check that we have used all the classes available
					my $found = 0;
					my $ccheck;
					my $b;
					my $nb_class_not_used = 0;
					foreach $ccheck ( @{$class} ) {
						$found = 0;
						foreach $b ( @{$book->{class}} ) {
							if ($ccheck eq $b) { $found = 1; }
						}
						if ( $found == 0 ) {
							print "$book->{ID}\t ";
							print( "Warning: Class not used ". $ccheck. "\n" );
							$nb_class_not_used ++;
						}
					}

					# in the case a class is not assigned and the number
					# of items is the same as the number of class, we just map them 1-to-1
					if (( $nb_class_not_used > 0 ) and
						( (scalar @{$class} ) == (scalar @{$book->{accno}}))) {
						print( "Warning: applied 1-to-1 mapping\n" );

						my $ic = 0;
						foreach ( @{$class} ) {
							$book->{class}->[$ic] = $_; 
							$ic ++;
						}
					}


					
					#foreach ( @{$book->{class}} ) {
					#	print	"All $_ \n"; 
					#}

	
					$i = 0;
					my $c = "";
					foreach ( @{$book->{accno}} ) {
						my $room = room_translation( $book->{accloc}->[$i], $documenttype );
						$c = " Error: missing class";
						$c = " --> " . $book->{class}->[$i] if $book->{class}->[$i] ne "";
						print "\t".$book->{accno}->[$i]. "\t" . $room. "\t". $c , "\n";
						$i ++;
					}
					print "-----------------------------------------------------------------------------------\n";


					#print "Warning: ". $book->{ID}. " Class is missing, using " . $book->{class} . " instead\n";

					#if ( @{$book->{accno}} !=  @{$book->{class}} ) {
					#	print "Error: class array is different size than accno array for record " . "$book->{ID} : [ @{$book->{accno}} ]  [ @{$book->{class}} ]" . "\n"; 
					#}

				}

				my $i = 0;
				#print( $book->{ID} .   "\n" );
				foreach ( @{$book->{accno}} ) {
					my $room = room_translation( $book->{accloc}->[$i], $documenttype );
					my ($itemstatus, $itemnotforloan, $itemlost)  = status_translation( $book->{accstatus}->[$i] ); 
					my $itemloantype = loantype_translation( $book->{accloantype}->[$i] ); 
					my $item = MARC::Field->new(
						'952',1,'',
							#8 => $documenttype,
							1 => $itemlost,
							5 => $itemloantype,
							7 => $itemnotforloan,
							a => "SCS",
							b => $location,
							c => $room,
							o => $book->{class}->[ $i ],
							p => $accprefix . $book->{accno}->[ $i ],
							y => $documenttype
					);
					$record->append_fields($item);
					$i ++;
					$documentcountitems ++;
				}
			} else {
				# In the case of a single item:

				#print	"All $book->{class}\n"; 
				my $room = room_translation( $book->{accloc}, $documenttype );
				my $class = class_translation( $book->{class} ); 
				my ($itemstatus, $itemnotforloan, $itemlost)  = status_translation( $book->{accstatus} ); 
				my $itemloantype = loantype_translation( $book->{accloantype} ); 
				my $item = MARC::Field->new(
					'952',1,'',
						#8 => $documenttype,
						1 => $itemlost,
						5 => $itemloantype,
						7 => $itemnotforloan,
						a => "SCS",
						b => $location,
						c => $room,
						o => $class,
						p => $accprefix . $book->{accno},
						y => $documenttype
				);
				$record->append_fields($item);
				$documentcountitems ++;
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
	} else {
		# item
		if ( exists $book->{holdings} ) {
			if( ref($book->{holdings}) ) {
				my $i = 0;
				#TODO ntloc doesn't exists
				my $room = room_translation( $book->{ntloc}, $documenttype );
				foreach ( @{$book->{holdings}} ) {
					my $item = MARC::Field->new(
						'952',1,'',
							#8 => "JRL",
							a => "SCS",
							b => $location,
							c => $room,
							y => $documenttype,
							z => $book->{holdings}->[ $i ]
					);
					$record->append_fields($item);
					$i ++;
				}
			} else {
				my $room = room_translation( $book->{ntloc}, $documenttype );
				my $item = MARC::Field->new(
					'952',1,'',
						#8 => "JRL",
						a => "SCS",
						b => $location,
						c => $room,
						y => $documenttype,
						z => $book->{holdings}
				);
				$record->append_fields($item);
			}
		} else {
			print "Information: Non-existant holding ". $book->{ID} . "\n";
		}
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

	# imprint
	if ( exists $book->{imprint} ) {
		my $imprint;
		#if ( $book->{imprint} =~ /(.*p\..*):(.*(ill|fac|port|biblio|tables|diag).*);(.*(cm|to|vo).*)/ ) {
		if ( $book->{imprint} =~ /(.*):(.*);(.*)/ ) {
			my $a = $1;
			my $b = $2;
			my $c = $3;
			$r260->add_subfields( a => $a );
			$r260->add_subfields( b => $b );
			$r260->add_subfields( c => $c );
			#$imprint = MARC::Field->new( 	'260',1,'', a => $a, b => $b, c => $c );
		} elsif ( $book->{imprint} =~ /(.*):(.*)/ ) {
			my $a = $1;
			my $b = $2;
			$r260->add_subfields( a => $a );
			$r260->add_subfields( b => $b );
			#$imprint = MARC::Field->new( 	'260',1,'', a => $a, b => $b );
		} else {
			$r260->add_subfields( a => $book->{imprint} );
			#$imprint = MARC::Field->new(	'260',1,'', a => $book->{imprint} );
		}
		#$record->append_fields($imprint);
	}



	# Remove the dummy subfields
	$r260->delete_subfield( code => 'z' );
	my @sr260 = $r260->subfields();

	# If more than 0 fields, we add it to the record
	if ( $#sr260 > 0 ) {
		$record->append_fields($r260);
	}

	if ( $documenttype ne "J" ) {
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
	} else {
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

	# keywords
	if ( exists $book->{keywords} ) {
		my $keywords;
		if( ref($book->{keywords}) ) {
			foreach ( @{$book->{keywords}} ) {
				$keywords = MARC::Field->new(
					'690',1,'',
						a => $_ #book->{keywords}
				);
				$record->append_fields($keywords);
			}
		} else {
			$keywords = MARC::Field->new(
				'690',1,'',
				a => $book->{keywords}
			);
			$record->append_fields($keywords);
		}
	}

	# series
	my $series = "";
	if ( exists $book->{series} ) {
		$series = $book->{series};
		$series =~ s/Maoileachlainnn/Maoileachlainn/g;
		#if ( $series =~ /Maoil/ ) {
		#	print "Maoil " . $book->{accloc} . "\n";
		#}
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
	my $lng;
	if ( $documenttype ne "J" ) {
		$lng = "110714s||||||||xx||||||||||||||||||eng|d";
	} else {
		# Language left as undefined for Serials
		$lng = "110714s||||||||xx||||||||||||||||||///|d";
	}
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

	# associated
	foreach my $assoc  (@{$assoclist->{record}}) {
		# stdno
		if ( exists $assoc->{stdno} ) {
			my $assoc_stdno;
			foreach ( $assoc->{stdno} ) {

				if ( $assoc->{stdno} eq $book->{stdno} ) {
					my $notes = "";
					if (exists $assoc->{notes}) {
						$notes = $assoc->{notes};
					}

					print( "Info: " . $book->{ID}. " ->> ". $notes . " " .$assoc->{url} . "\n" );
					my $assoc_url_note = MARC::Field->new('500',1,'',a => "URL: " . $notes . " <a href='" . $assoc->{url} . "'>". $assoc->{url} . "</a>");
					$record->append_fields($assoc_url_note);
				}

			}
		}

	}

	# Write the new MARC record
	print $fh $record->as_usmarc();
	$documentcount ++;

	# Not freeing the memory, but it doesn't matter =-D
}

print "Records:", $documentcount, " Items:", $documentcountitems, " Skipped:", $documentskip, " Unknown:", $documenttypeunknown, " Total:", $documentcount+$documentskip, "\n";

close($fh);

