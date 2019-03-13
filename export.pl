#!/usr/bin/env perl

use strict;
use DBI;
use DBD::mysql;
use JSON::XS;
use Getopt::Long;

my %material_mapping = (
    1       => 'Antimony',
    2       => 'Arsenic',
    3       => 'Cadmium',
    4       => 'Carbon',
    5       => 'Chromium',
    6       => 'Germanium',
    7       => 'Iron',
    8       => 'Manganese',
    9       => 'Mercury',
    10      => 'Molybdenum',
    11      => 'Nickel',
    12      => 'Niobium',
    13      => 'Phosphorus',
    14      => 'Polonium',
    15      => 'Ruthenium',
    16      => 'Selenium',
    17      => 'Sulphur',
    18      => 'Technetium',
    19      => 'Tellurium',
    20      => 'Tin',
    21      => 'Tungsten',
    22      => 'Vanadium',
    23      => 'Yttrium',
    24      => 'Zinc',
    25      => 'Zirconium',
    26      => 'Rhenium',
    27      => 'Lead',
    28      => 'Boron',
);

my %solid_mapping = (
    1          => 'Ice',
    2          => 'Metal',
    3          => 'Rock',
);

my %atmosphere_mapping = (
     1      => 'Argon',
     2      => 'Ammonia',
     3      => 'Carbon dioxide',
     4      => 'Hydrogen',
     5      => 'Helium',
     6      => 'Iron',
     7      => 'Neon',
     8      => 'Methane',
     9      => 'Nitrogen',
     10      => 'Oxygen',
     11      => 'Silicates',
     12      => 'Sulphur dioxide',
     13      => 'Water',
);

my %ring_mapping = (
    1 => 'Icy',
    2 => 'Metallic',
    3 => 'Metal Rich',
    4 => 'Rocky',
);

my %star_mapping = (
          1     => 'O (Blue-White) Star',
          2     => 'B (Blue-White) Star',
          
          3     => 'A (Blue-White) Star',
          301   => 'A (Blue-White super giant) Star',
          
          4     => 'F (White) Star',
          401   => 'F (White super giant) Star',
          
          5     => 'G (White-Yellow) Star',
          5001  => 'G (White-Yellow super giant) Star', # Not returned by the game so estimated based on F (White super giant) Star temperature between 5200 and 6000
          
          6     => 'K (Yellow-Orange) Star',
          601   => 'K (Yellow-Orange giant) Star',
          
          7     => 'M (Red dwarf) Star',
          701   => 'M (Red giant) Star',
          702   => 'M (Red super giant) Star',
          
          8     => 'L (Brown dwarf) Star',
          9     => 'T (Brown dwarf) Star',
         10     => 'Y (Brown dwarf) Star',
        
        # Proto stars
         11     => 'T Tauri Star',
         12     => 'Herbig Ae/Be Star',
        
        # Wolf-Rayet
         21     => 'Wolf-Rayet Star',
         22     => 'Wolf-Rayet N Star',
         23     => 'Wolf-Rayet NC Star',
         24     => 'Wolf-Rayet C Star',
         25     => 'Wolf-Rayet O Star',
        
        # Carbon stars
         31     => 'CS Star', # Check in game
         32     => 'C Star',
         33     => 'CN Star',
         34     => 'CJ Star', # Check in game
         35     => 'CH Star', # Check in game
         36     => 'CHd Star', # Check in game
        
         41     => 'MS-type Star', # Check in game
         42     => 'S-type Star', # Check in game
        
        # White dwarfs
         51     => 'White Dwarf (D) Star',
        501     => 'White Dwarf (DA) Star',
        502     => 'White Dwarf (DAB) Star',
        503     => 'White Dwarf (DAO) Star',
        504     => 'White Dwarf (DAZ) Star',
        505     => 'White Dwarf (DAV) Star',
        506     => 'White Dwarf (DB) Star',
        507     => 'White Dwarf (DBZ) Star',
        508     => 'White Dwarf (DBV) Star',
        509     => 'White Dwarf (DO) Star',
        510     => 'White Dwarf (DOV) Star',
        511     => 'White Dwarf (DQ) Star',
        512     => 'White Dwarf (DC) Star',
        513     => 'White Dwarf (DCV) Star',
        514     => 'White Dwarf (DX) Star',
        
         91     => 'Neutron Star',
         92     => 'Black Hole', # Check in game
         93     => 'Supermassive Black Hole', # Check in game
         
         94     => 'X', # Exotic?? # Check in game
        
        111     => 'RoguePlanet', # Check in game
        112     => 'Nebula', # Check in game
        113     => 'StellarRemnantNebula', # Check in game
);

my %planet_mapping = (
         1      => 'Metal-rich body',
         2      => 'High metal content world',
         
        11      => 'Rocky body',
        12      => 'Rocky Ice world', # Check in game
        
        21      => 'Icy body',
        
        31      => 'Earth-like world',
        
        41      => 'Water world',
        42      => 'Water giant', # Check in game
        43      => 'Water giant with life', # Check in game    
        
        51      => 'Ammonia world',
        
        61      => 'Gas giant with water-based life', # Check in game
        62      => 'Gas giant with ammonia-based life', # Check in game
        
        71      => 'Class I gas giant',
        72      => 'Class II gas giant',
        73      => 'Class III gas giant',
        74      => 'Class IV gas giant',
        75      => 'Class V gas giant',
        
        81      => 'Helium-rich gas giant',
        82      => 'Helium gas giant',
);

Getopt::Long::GetOptions(
	"batch_size=i" => \(my $batch_size),
	"limit=i" => \(my $limit),
);


my $dbh = DBI->connect("DBI:mysql:database=edsm;host=localhost",'elite_dangerous','5u0r36n4d_3t71le');


my $body_sth = $dbh->prepare(qq|
    SELECT `systemsBodies`.*, `systemsBodiesOrbital`.*, `systemsBodiesSurface`.*, `systemsBodiesParents`.*, `systems`.`id64` AS `systemId64`, `systems`.`name` AS `systemName`, `systemsBodiesOrbital`.*, `systemsBodiesSurface`.*, `systemsBodiesParents`.*
    FROM
        `systemsBodies`
        INNER JOIN `systems` ON systemsBodies.refSystem = systems.id
        LEFT JOIN `systemsBodiesOrbital` ON systemsBodies.id = systemsBodiesOrbital.refBody
        LEFT JOIN `systemsBodiesSurface` ON systemsBodies.id = systemsBodiesSurface.refBody
        LEFT JOIN `systemsBodiesParents` ON systemsBodies.id = systemsBodiesParents.refBody
        LEFT JOIN `systemsHides` ON systemsBodies.id = systemsHides.refSystem
    WHERE
        (systemsBodies.id > ?) AND (systemsBodies.id <= ?)
        AND systemsHides.refSystem IS NULL
    ORDER BY `systemsBodies`.`id` ASC
    LIMIT 250000
|);

my $material_sth = $dbh->prepare(qq|
    SELECT *
    FROM systemsBodiesMaterials
    WHERE refBody = ?
|);

my $atmosphere_composition_sth = $dbh->prepare(qq|
    SELECT *
    FROM systemsBodiesAtmosphereComposition
    WHERE refBody = ?
|);

my $solid_composition_sth = $dbh->prepare(qq|
    SELECT *
    FROM systemsBodiesSolidComposition
    WHERE refBody = ?
|);

my $belt_sth = $dbh->prepare(qq|
    SELECT *
    FROM systemsBodiesBelts
    WHERE refBody = ?
|);

my $ring_sth = $dbh->prepare(qq|
    SELECT *
    FROM systemsBodiesRings
    WHERE refBody = ?
|);

my $max_sth = $dbh->prepare('SELECT max(id) FROM systemsBodies');
$max_sth->execute();
my ($max_body_id) = $max_sth->fetchrow_array;

my $current_body_id = 0;

print "[\n";

my $count = 0;
while ($current_body_id < $max_body_id) {
	$count++;
    $body_sth->execute($current_body_id,$max_body_id);
    while (my $body_row = $body_sth->fetchrow_hashref()) {
        my %materials;
        $material_sth->execute($body_row->{id});
        while (my $material_row = $material_sth->fetchrow_hashref()) {
            $materials{$material_mapping{$material_row->{refMaterial}}} = $material_row->{percent};
        }
        my %solids;
        $solid_composition_sth->execute($body_row->{id});
        while (my $solid_row = $solid_composition_sth->fetchrow_hashref()) {
            $solids{$solid_mapping{$solid_row->{refComposition}}} = $solid_row->{percent};
        }
        my %atmospheres;
        $atmosphere_composition_sth->execute($body_row->{id});
        while (my $atmosphere_row = $atmosphere_composition_sth->fetchrow_hashref()) {
            $atmospheres{$atmosphere_mapping{$atmosphere_row->{refComposition}}} = $atmosphere_row->{percent};
        }

        my @belts;
        $belt_sth->execute($body_row->{id});
        while (my $belt_row = $belt_sth->fetchrow_hashref()) {
            push @belts,{
                name => $belt_row->{name},
                type => $ring_mapping{$belt_row->{type}},
                mass => $belt_row->{mass},
                innerRadius => $belt_row->{iRad},
                outerRadius => $belt_row->{oRad},
            };
        }

        my @rings;
        $ring_sth->execute($body_row->{id});
        while (my $ring_row = $ring_sth->fetchrow_hashref()) {
            push @rings,{
                name => $ring_row->{name},
                type => $ring_mapping{$ring_row->{type}},
                mass => $ring_row->{mass},
                innerRadius => $ring_row->{iRad},
                outerRadius => $ring_row->{oRad},
            };
        }

        print "\t" . JSON::XS::encode_json({
            id => $body_row->{id},
            id64 => $body_row->{id64}, # not actually id64, needs to be combined with system id64
            bodyId => $body_row->{id64},
            coords => {
                    x => $body_row->{x},
                    y => $body_row->{y},
                    z => $body_row->{z},
            },
            type => (($body_row->{group} == 1) ? 'Star' : 'Planet'),
            subtype => (($body_row->{group} == 1) ? $star_mapping{$body_row->{type}} : $planet_mapping{$body_row->{type}}),

            belts => \@belts,
            rings => \@rings,
            materials => \%materials,
            solidComposition => \%solids,
            atmosphereComposition => \%solids,
        });
    }
    if ($limit > 0 && $count > $limit) {
        last;
    }
}

print "]\n";
