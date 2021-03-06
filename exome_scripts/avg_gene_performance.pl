#!/usr/bin/perl 
# 
# 
# 
# 
# Kim Brugger (04 Dec 2013), contact: kim.brugger@easih.ac.uk

use strict;
use warnings;
use Data::Dumper;

use lib '/software/packages/VCFdb/modules';
use CTRU::VCFdb;


#exit;
use Getopt::Std;

my $dbhost = 'mgsrv01';
my $dbname = 'VCFdb_exome';

my $dbi = CTRU::VCFdb::connect($dbname, $dbhost, "easih_admin", "easih");


my $gene_name = shift;



if ( $gene_name ) {
  print_gene_performance( $gene_name);
}
else {
  my %genes;
  map {$$_{name} =~ s/_Exon.*//ig; $genes{ $$_{ 'name' }}++ } CTRU::VCFdb::fetch_regions();

#  print Dumper( \%genes );

  foreach my $gene ( sort keys %genes ) {
    print_gene_performance( $gene);
  }

}



# 
# 
# 
# Kim Brugger (09 Dec 2013)
sub print_gene_performance {
  my  ( $gene_name ) = @_;
  
  my @exons = CTRU::VCFdb::fetch_regions_by_gene($gene_name);

#  print Dumper( \@exons );
#  exit;


  foreach my $exon ( sort{ my $A = $$a{name};
			   my $B = $$b{name};
			   $A =~ s/.*exon//i;
			   $B =~ s/.*exon//i;
			   $A <=> $B } @exons ) {
  
    my @coverages = CTRU::VCFdb::fetch_coverages_by_rid( $$exon{ rid });
    my (@reads, @min_depth);
    foreach my $coverage ( @coverages ) {
      my $sample_sequence_hash = CTRU::VCFdb::fetch_sample_sequence_hash( $$coverage{ ssid } );
      next if ( ! $$sample_sequence_hash{ total_reads });
      print join("\t", $$exon{name}, 
		 $$sample_sequence_hash{ name },
		 $$sample_sequence_hash{ total_reads }, 
		 $$sample_sequence_hash{ mapped_reads } - $$sample_sequence_hash{ duplicate_reads }, 
		 $$coverage{min}) . "\n" if ( 0 );
      push @min_depth, $$coverage{min} || 0;
      push @reads, $$sample_sequence_hash{ total_reads };
#    push @reads, $$sample_sequence_hash{ mapped_reads } - $$sample_sequence_hash{ duplicate_reads };
    }
    
#  print "$$exon{'name'}:::  @min_depth \n";
    
    if (! @min_depth) {
      printf("$$exon{chr}:$$exon{start}-$$exon{end}\t$$exon{name}\tNo-Data\n");
    }
    else {
      my( $intercept, $slope) = linear_regression(\@reads, \@min_depth);
      
      my $exp_depth_30M = $intercept + $slope*30_000_000;
      my $reads_for_20x = (20 - $intercept) / $slope if ( $slope > 0);
      $reads_for_20x = 0 if ( $slope <= 0);

      
      $reads_for_20x /= 1000000;

      printf("$$exon{chr}:$$exon{start}-$$exon{end}\t$$exon{name}\t%.2f\t%dM\n", $exp_depth_30M, $reads_for_20x);
    }
    
#  print Dumper( \@coverages );
#  exit;
  }
}


# 
# 
# 
# Kim Brugger (06 Dec 2013)
sub linear_regression {
  my ( $xs, $ys ) = @_;

  my $N = @$xs;

  my ( $sumX, $sumY, $sumXY, $sumXX) = (0,0,0,0);

  for(my $i=0;$i < $N; $i++ ) {

    $sumX  += $$xs[ $i ];
    $sumY  += $$ys[ $i ];
    $sumXX += $$xs[ $i ] * $$xs[ $i ];
    $sumXY += $$xs[ $i ] * $$ys[ $i ];

  }

#  print join("\t", $sumX, $sumY, $sumXX, $sumXY, $N) . "\n";

  my $slope = ($N*$sumXY - ($sumX*$sumY))/( $N*$sumXX - $sumX*$sumX);

#  print "  my $slope = ($N*$sumXY - ($sumX*$sumY))/( $N*$sumXX - $sumX * $sumX);\n";
  
  my $intercept = ($sumY - $slope*$sumX) / $N;

#  print "$slope $intercept\n";

  return ($intercept, $slope);
  
}

