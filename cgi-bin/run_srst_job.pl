#!/usr/bin/perl -w

use strict;
use Email::Valid;
use Email::Send;
use Email::Simple::Creator;
use Email::Send::Gmail;
use File::Basename;


#######
# Takes in job name, jobdir, all parameters for SRST
# Runs SRST, makes output index.html, and sends an email to the user
#
#######
#$jobname $organism $email $datadir_prefix $jobfile_prefix $virdb $read_one_filename $read_two_filename $min_cov $max_divergence

my $jobname=$ARGV[0];
my $organism=$ARGV[1];
my $email=$ARGV[2];
my $datadir_prefix=$ARGV[3];
my $jobfile_prefix =$ARGV[4];
my $virdb=$ARGV[5];
my $read_one_filename = $ARGV[6];
my $read_two_filename = $ARGV[7];
my $min_cov = $ARGV[8];
my $max_divergence = $ARGV[9];

#get the parameter from name field
# and store in $value variable.

if ($read_two_filename eq "NONE") {
	$read_two_filename = "";
}

&run_job;

my $results_email = Email::Simple->create(
	header => [
		To		=>	$email,
		From	=>	'"Chang Lab" <osu.chang@gmail.com>',
		Subject	=>  "GALL-ID Virulence Gene ID results for $jobname",
	],	
	body => "Your recently submitted job $jobname has completed. You can view the results of the analysis here:\nhttp://localhost/~alex/Gall-ID/files/tmp/$jobfile_prefix/index.html\n\nThe results of the analysis will be available for 7 days before being deleted. Thank you for using this service. Do not reply to this message.\n",
);

my $email_sender = Email::Send->new(
{	mailer		=> 'Gmail',
	mailer_args => [
		username => 'emailname',
		password => 'password',
	]
}
);
eval { $email_sender->send($results_email) };
die "Error sending email: $@" if $@;



#Run SRST and make the output index file.
sub run_job{
	my $html_template_beginning = <<EOF
	<!DOCTYPE html>
	<html lang="en"><head>
	<meta http-equiv="content-type" content="text/html; charset=UTF-8">
    <meta charset="utf-8">
    <title>Gall-ID | Vir-Search: $jobname</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="">
    <meta name="author" content="root" >

    <!-- Le styles -->
    <link href="http://localhost/~alex/Gall-ID/Bootstrap_files/bootstrap.css" rel="stylesheet">
    <style>
      body {
        padding-top: 60px; /* 60px to make the container go all the way to the bottom of the topbar */
      }
    </style>
    <link href="http://localhost/~alex/Gall-ID/Bootstrap_files/bootstrap-responsive.css" rel="stylesheet">
        <link href="http://localhost/~alex/Gall-ID/Bootstrap_files/phytophthora-lab.css" rel="stylesheet">

    <!-- Fav and touch icons -->
    <link rel="apple-touch-icon-precomposed" sizes="144x144" href="http://twitter.github.com/bootstrap/assets/ico/apple-touch-icon-144-precomposed.png">
    <link rel="apple-touch-icon-precomposed" sizes="114x114" href="http://twitter.github.com/bootstrap/assets/ico/apple-touch-icon-114-precomposed.png">
      <link rel="apple-touch-icon-precomposed" sizes="72x72" href="http://twitter.github.com/bootstrap/assets/ico/apple-touch-icon-72-precomposed.png">
                    <link rel="apple-touch-icon-precomposed" href="http://twitter.github.com/bootstrap/assets/ico/apple-touch-icon-57-precomposed.png">
                                   <link rel="shortcut icon" href="http://phytophthora-id.org/img/customIcon.png">
	</head>
	<body>
	<div class="navbar navbar navbar-fixed-top">
      <div class="navbar-inner">
        <div class="container">
          <button type="button" class="btn btn-navbar" data-toggle="collapse" data-target=".nav-collapse">
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </button>
          <a class="brand" href="http://localhost/~alex/Gall-ID/index.html">Gall-ID</a>
          <div class="nav-collapse collapse">
            <ul class="nav">
              <li class="http://localhost/~alex/Gall-ID/index.html"><a href="/~alex/Gall-ID/index.html">Home</a></li>
              <li><a href="http://localhost/~alex/Gall-ID/genome-id-agro.html">Agro-type</a></li>
              <li><a href="http://localhost/~alex/Gall-ID/genome-id-rhodo.html">Rhodo-type</a></li>
              <li><a href="http://localhost/~alex/Gall-ID/wgs-id.html">Whole Genome Analysis</a></li>
              <li><a href="http://localhost/~alex/Gall-ID/vir-finder.html">Vir-Search</a></li>
			  <li><a href="http://localhost/~alex/Gall-ID/about.html">About</a></li>            </ul>
          </div><!--/.nav-collapse -->
        </div>
      </div>
    </div>

    <div class="container">
	<h1>Virulence Gene Search results</h1>
 	<p><strong>Submitted job name:</strong> $jobname<br>
	<strong>Organism:</strong> $organism<br>
	<strong>Forward/Single reads file:</strong> $read_one_filename<br>
	<strong>Reverse reads file:</strong> $read_two_filename<br>
	<strong>Minimum % coverage of database gene:</strong> $min_cov%<br>
	<strong>Maximum % divergence from database gene:</strong> $max_divergence%<br>
	<strong>Output file prefix:</strong> $jobfile_prefix<br>
	<strong>Email:</strong> $email<br>
	</p>
	<hr></hr>
   	<h2 class="text-info"> Result table </h2>
EOF
;
		##########

		my $result_table;

		my $jobdir = "$datadir_prefix/tmp/$jobfile_prefix";

		#Prepare SRST2 command
		my $command;
		if($read_two_filename eq "") {
			$ENV{ 'PYTHONPATH' } = '/usr/local/Cellar/python/2.7.6/Frameworks/Python.framework/Versions/2.7/lib/python2.7/site-packages/setuptools-2.0.1-py2.7.egg/:/usr/local/Cellar/python/2.7.6/Frameworks/Python.framework/Versions/2.7/lib/python2.7/site-packages/setuptools-2.0.1-py2.7.egg/:/usr/local/Cellar/python/2.7.6/Frameworks/Python.framework/Versions/2.7/lib/python2.7/site-packages/pip-1.4.1-py2.7.egg:/usr/local/Cellar/python/2.7.6/Frameworks/Python.framework/Versions/2.7/lib/python2.7/site-packages/Cython-0.20.1-py2.7-macosx-10.9-x86_64.egg:/opt/local/src/scipy:/usr/local/Cellar/python/2.7.6/Frameworks/Python.framework/Versions/2.7/lib/python2.7/site-packages/docutils-0.12-py2.7.egg:/usr/local/lib/python2.7/site-packages/setuptools-2.0.1-py2.7.egg:/usr/local/lib/python2.7/site-packages/pip-1.4.1-py2.7.egg:/usr/local/lib/python2.7/site-packages/Cython-0.20.1-py2.7-macosx-10.9-x86_64.egg:/usr/local/lib/python2.7/site-packages/docutils-0.12-py2.7.egg:/usr/local/Cellar/python/2.7.6/Frameworks/Python.framework/Versions/2.7/lib/python27.zip:/usr/local/Cellar/python/2.7.6/Frameworks/Python.framework/Versions/2.7/lib/python2.7:/usr/local/Cellar/python/2.7.6/Frameworks/Python.framework/Versions/2.7/lib/python2.7/plat-darwin:/usr/local/Cellar/python/2.7.6/Frameworks/Python.framework/Versions/2.7/lib/python2.7/plat-mac:/usr/local/Cellar/python/2.7.6/Frameworks/Python.framework/Versions/2.7/lib/python2.7/plat-mac/lib-scriptpackages:/usr/local/Cellar/python/2.7.6/Frameworks/Python.framework/Versions/2.7/lib/python2.7/lib-tk:/usr/local/Cellar/python/2.7.6/Frameworks/Python.framework/Versions/2.7/lib/python2.7/lib-old:/usr/local/Cellar/python/2.7.6/Frameworks/Python.framework/Versions/2.7/lib/python2.7/lib-dynload:/usr/local/Cellar/python/2.7.6/Frameworks/Python.framework/Versions/2.7/lib/python2.7/site-packages:/Library/Python/2.7/site-packages:/usr/local/lib/python2.7/site-packages:/usr/local/lib/python2.7/site-packages/';
			$ENV{ 'PATH' } = '/usr/local/bin:/usr/bin:/bin';
			#Working with single end data
			$command = "/usr/local/bin/python_test /usr/local/bin/srst2 --input_se $datadir_prefix/tmp/$jobfile_prefix/read_1.fastq --log --max_divergence $max_divergence --min_coverage $min_cov --output $datadir_prefix/tmp/$jobfile_prefix/$jobfile_prefix.out --gene_db $datadir_prefix/$virdb.fasta";
		} else {
			#Working with paired end data
			$command = "/usr/local/bin/python_test /usr/local/bin/srst2 --input_pe $datadir_prefix/tmp/$jobfile_prefix/read_1.fastq $datadir_prefix/tmp/$jobfile_prefix/read_2.fastq --max_divergence $max_divergence --min_coverage $min_cov --log --output $datadir_prefix/tmp/$jobfile_prefix/$jobfile_prefix.out --gene_db $datadir_prefix/$virdb.fasta";
		}

		#Run SRST2
		#my $result = system("$command");
		my $result = 0;
		if ($result != 0) {
			system("rm $datadir_prefix/tmp/$jobfile_prefix/read_1.fastq");
			$result_table .= "An Error occurred. Please check your input files and try again. Or contact us at osu.chang\@gmail.com";
			$result_table .= "Command: $command";
		} else {
		#Check the analysis and print results
			system("cp $datadir_prefix/testinput3.txt $datadir_prefix/tmp/$jobfile_prefix/$jobfile_prefix.out__fullgenes__$virdb\__results.txt");
			my $outputfile = "$datadir_prefix/tmp/$jobfile_prefix/$jobfile_prefix.out__fullgenes__$virdb\__results.txt";
			my $publicoutputfile = "http://localhost/~alex/Gall-ID/files/tmp/$jobfile_prefix/$jobfile_prefix.out__fullgenes__$virdb\__results.txt";
		
			my $found_img = "<center><img src=\"http://localhost/~alex/Gall-ID/img/virulence_found.png\"></img></center>";
			my $notfound_img = "<center><img src=\"http://localhost/~alex/Gall-ID/img/virulence_notfound.png\"></img></center>";
	

			$result_table .= "<strong>SRST2 command:</strong> $command<br><strong>Output filename:</strong> <a href=\"$outputfile\">$publicoutputfile</a><br><br>";
	
			if ($organism eq "Agrobacterium") {
				my $output_fh;
				my %gene_hash;
				#Check if there is an output file, meaning we found hits
				#then read into a hash keyed by gene name
        	   	if( -s $outputfile ) {
        	    	open($output_fh, $outputfile) || die "failed to read output file: $!";
					my $header = <$output_fh>;
					while (my $line = <$output_fh>) {
							chomp $line;
					my @line = split(/\s+/, $line);
						@{ $gene_hash{$line[2]} } = @line;
					}
        	    }
			
				#Check for each virulence gene and print out results
				my $virB1_status = $notfound_img;
				my $virB1_coverage = "-";
				my $virB1_depth = "-";
        	    if (exists $gene_hash{"VirB1"}) {
        	        $virB1_status = $found_img;
           		 	$virB1_coverage = @{$gene_hash{"VirB1"}}[4];
					$virB1_depth = @{$gene_hash{"VirB1"}}[5];
				}
	
				my $virB2_status = $notfound_img;
	            my $virB2_coverage = "-";
	            my $virB2_depth = "-";
	            if (exists $gene_hash{"VirB2"}) {
	                $virB2_status = $found_img;
	                $virB2_coverage = @{$gene_hash{"VirB2"}}[4];
	                $virB2_depth = @{$gene_hash{"VirB2"}}[5];
	            }

				my $virB3_status = $notfound_img;
	            my $virB3_coverage = "-";
	            my $virB3_depth = "-";
	            if (exists $gene_hash{"VirB3"}) {
	                $virB3_status = $found_img;
	                $virB3_coverage = @{$gene_hash{"VirB3"}}[4];
	                $virB3_depth = @{$gene_hash{"VirB3"}}[5];
	            }

				my $virB4_status = $notfound_img;
	            my $virB4_coverage = "-";
	            my $virB4_depth = "-";
	            if (exists $gene_hash{"VirB4"}) {
	                $virB4_status = $found_img;
	                $virB4_coverage = @{$gene_hash{"VirB4"}}[4];
	                $virB4_depth = @{$gene_hash{"VirB4"}}[5];
	            }

				my $virB5_status = $notfound_img;
	            my $virB5_coverage = "-";
	            my $virB5_depth = "-";
   		        if (exists $gene_hash{"VirB5"}) {
    	            $virB5_status = $found_img;
        	        $virB5_coverage = @{$gene_hash{"VirB5"}}[4];
            	    $virB5_depth = @{$gene_hash{"VirB5"}}[5];
           	 	}


            	my $virB6_status = $notfound_img;
            	my $virB6_coverage = "-";
            	my $virB6_depth = "-";
            	if (exists $gene_hash{"VirB6"}) {
            	    $virB6_status = $found_img;
            	    $virB6_coverage = @{$gene_hash{"VirB6"}}[4];
            	    $virB6_depth = @{$gene_hash{"VirB6"}}[5];
            	}

            	my $virB7_status = $notfound_img;
          		my $virB7_coverage = "-";
            	my $virB7_depth = "-";
            	if (exists $gene_hash{"VirB7"}) {
            	    $virB7_status = $found_img;
            	    $virB7_coverage = @{$gene_hash{"VirB7"}}[4];
            	    $virB7_depth = @{$gene_hash{"VirB7"}}[5];
            	}

            	my $virB8_status = $notfound_img;
            	my $virB8_coverage = "-";
            	my $virB8_depth = "-";
            	if (exists $gene_hash{"VirB8"}) {
            	    $virB8_status = $found_img;
            	    $virB8_coverage = @{$gene_hash{"VirB8"}}[4];
            	    $virB8_depth = @{$gene_hash{"VirB8"}}[5];
            	}

            	my $virB9_status = $notfound_img;
            	my $virB9_coverage = "-";
            	my $virB9_depth = "-";
            	if (exists $gene_hash{"VirB9"}) {
            	    $virB9_status = $found_img;
            	    $virB9_coverage = @{$gene_hash{"VirB9"}}[4];
            	    $virB9_depth = @{$gene_hash{"VirB9"}}[5];
            	}

            	my $virB10_status = $notfound_img;
            	my $virB10_coverage = "-";
            	my $virB10_depth = "-";
            	if (exists $gene_hash{"VirB10"}) {
            	    $virB10_status = $found_img;
            	    $virB10_coverage = @{$gene_hash{"VirB10"}}[4];
            	    $virB10_depth = @{$gene_hash{"VirB10"}}[5];
            	}

            	my $virB11_status = $notfound_img;
            	my $virB11_coverage = "-";
	        	my $virB11_depth = "-";
            	if (exists $gene_hash{"VirB11"}) {
            	    $virB11_status = $found_img;
            	    $virB11_coverage = @{$gene_hash{"VirB11"}}[4];
            	    $virB11_depth = @{$gene_hash{"VirB11"}}[5];
            	}

            	my $virD4_status = $notfound_img;
            	my $virD4_coverage = "-";
            	my $virD4_depth = "-";
            	if (exists $gene_hash{"VirD4"}) {
            	    $virD4_status = $found_img;
            	    $virD4_coverage = @{$gene_hash{"VirD4"}}[4];
            	    $virD4_depth = @{$gene_hash{"VirD4"}}[5];
            	}

            	my $virD2_status = $notfound_img;
            	my $virD2_coverage = "-";
            	my $virD2_depth = "-";
            	if (exists $gene_hash{"VirD2"}) {
            	    $virD2_status = $found_img;
            	    $virD2_coverage = @{$gene_hash{"VirD2"}}[4];
            	    $virD2_depth = @{$gene_hash{"VirD2"}}[5];
            	}

            	my $virE2_status = $notfound_img;
            	my $virE2_coverage = "-";
            	my $virE2_depth = "-";
            	if (exists $gene_hash{"VirE2"}) {
            	    $virE2_status = $found_img;
            	    $virE2_coverage = @{$gene_hash{"VirE2"}}[4];
            	    $virE2_depth = @{$gene_hash{"VirE2"}}[5];
            	}

            	my $GALLS_status = $notfound_img;
            	my $GALLS_coverage = "-";
            	my $GALLS_depth = "-";
            	if (exists $gene_hash{"GALLS"}) {
            	    $GALLS_status = $found_img;
            	    $GALLS_coverage = @{$gene_hash{"GALLS"}}[4];
            	    $GALLS_depth = @{$gene_hash{"GALLS"}}[5];
            	}

            	my $virD5_status = $notfound_img;
            	my $virD5_coverage = "-";
            	my $virD5_depth = "-";
            	if (exists $gene_hash{"VirD5"}) {
            	    $virD5_status = $found_img;
            	    $virD5_coverage = @{$gene_hash{"VirD5"}}[4];
            	    $virD5_depth = @{$gene_hash{"VirD5"}}[5];
            	}

            	my $virE3_status = $notfound_img;
            	my $virE3_coverage = "-";
            	my $virE3_depth = "-";
            	if (exists $gene_hash{"VirE3"}) {
            	    $virE3_status = $found_img;
            	    $virE3_coverage = @{$gene_hash{"VirE3"}}[4];
            	    $virE3_depth = @{$gene_hash{"VirE3"}}[5];
            	}
	
    	        my $virF_status = $notfound_img;
        	    my $virF_coverage = "-";
           		my $virF_depth = "-";
           		if (exists $gene_hash{"VirF"}) {
            	    $virF_status = $found_img;
            	    $virF_coverage = @{$gene_hash{"VirF"}}[4];
            	    $virF_depth = @{$gene_hash{"VirF"}}[5];
            	}

				my $recA_status = $notfound_img;
				my $recA_coverage = "-";
				my $recA_depth = "-";
				if (exists $gene_hash{"recA"}) {
					$recA_status = $found_img;
					$recA_coverage = @{$gene_hash{"recA"}}[4];
					$recA_depth = @{$gene_hash{"recA"}}[5];
				}

				my $glnII_status = $notfound_img;
				my $glnII_coverage = "-";
				my $glnII_depth = "-";
				if (exists $gene_hash{"glnII"}) {
					$glnII_status = $found_img;
					$glnII_coverage = @{$gene_hash{"glnII"}}[4];
					$glnII_depth = @{$gene_hash{"glnII"}}[5];
																				                
				} 

				my $dnaK_status = $notfound_img;
				my $dnaK_coverage = "-";
				my $dnaK_depth = "-";
				if (exists $gene_hash{"dnaK"}) {
					$dnaK_status = $found_img;
					$dnaK_coverage = @{$gene_hash{"dnaK"}}[4];
					$dnaK_depth = @{$gene_hash{"dnaK"}}[5];	
				}

				my $rpoB_status = $notfound_img;
				my $rpoB_coverage = "-";
				my $rpoB_depth = "-";
				if (exists $gene_hash{"rpoB"}) {
					$rpoB_status = $found_img;
					$rpoB_coverage = @{$gene_hash{"rpoB"}}[4];
					$rpoB_depth = @{$gene_hash{"rpoB"}}[5];
				}


				my $gyrB_status = $notfound_img;
				my $gyrB_coverage = "-";
				my $gyrB_depth = "-";
				if (exists $gene_hash{"gyrB"}) {
					$gyrB_status = $found_img;
					$gyrB_coverage = @{$gene_hash{"gyrB"}}[4];	
					$gyrB_depth = @{$gene_hash{"gyrB"}}[5];
				}

				my $truA_status = $notfound_img;
				my $truA_coverage = "-";
				my $truA_depth = "-";
				if (exists $gene_hash{"truA"}) {
					$truA_status = $found_img;
					$truA_coverage = @{$gene_hash{"truA"}}[4];                  
					$truA_depth = @{$gene_hash{"truA"}}[5];
				} 

				my $thrA_status = $notfound_img;
				my $thrA_coverage = "-";
				my $thrA_depth = "-";
				if (exists $gene_hash{"thrA"}) {
					$thrA_status = $found_img;
					$thrA_coverage = @{$gene_hash{"thrA"}}[4];                  
					$thrA_depth = @{$gene_hash{"thrA"}}[5];															                
				} 


				#Print out results table
				$result_table .= "<em>Agrobacterium tumefaciens</em> C58 genes were used as reference for all virulence genes except for GALLS which came from strain ...";
				$result_table .= "<div class=\"row\">";
				$result_table .= "<div class=\"span6\">";	
				$result_table .= "<table class=\"table table-bordered table-hover\">";
				$result_table .= "<caption><h4>Virulence Genes</h4></caption>";
				$result_table .= "<thead><td>Found</td><td>Gene</td><td>Coverage (%)</td><td>Depth</td></thead>";
				$result_table .= "<tbody><tr><td style=\"width: 50px;\">$virD2_status</td><td>VirD2</td><td>$virD2_coverage</td><td>$virD2_depth</td></tr>";
				$result_table .= "<tr><td>$virE2_status</td><td>VirE2</td><td>$virE2_coverage</td><td>$virE2_depth</td></tr>";
				$result_table .= "<tr><td>$GALLS_status</td><td>GALLS</td><td>$GALLS_coverage</td><td>$GALLS_depth</td></tr></tbody></table>";
			
				$result_table .= "<table class=\"table table-bordered table-hover\">";
				$result_table .= "<caption><h4>Nonessential Effectors</h4></caption>";
  	    	    $result_table .= "<thead><td>Found</td><td>Gene</td><td>Coverage (%)</td><td>Depth</td></thead>";
				$result_table .= "<tbody><tr><td style=\"width: 50px;\">$virD5_status</td><td>VirD5</td><td>$virD5_coverage</td><td>$virD5_depth</td></tr>";
	    	    $result_table .= "<tr><td>$virE3_status</td><td>VirE3</td><td>$virE3_coverage</td><td>$virE3_depth</td></tr>";
	    	    $result_table .= "<tr><td>$virF_status</td><td>VirF</td><td>$virF_coverage</td><td>$virF_depth</td></tr>";
	    	    $result_table .= "</tbody></table>";
				$result_table .= "</div>";
				
				$result_table .= "<div class=\"span6\">";
				$result_table .= "<table class=\"table table-bordered table-hover\">";
				$result_table .= "<caption><h4>Type IV Secretion System</h4></caption>";
				$result_table .= "<thead><td>Found</td><td>Gene</td><td>Coverage (%)</td><td>Depth</td></thead>";
				$result_table .= "<tbody><tr><td style=\"width:50px;\">$virB1_status</td><td>VirB1</td><td>$virB1_coverage</td><td>$virB1_depth</td></tr>";
				$result_table .= "<tr><td>$virB2_status</td><td>VirB2</td><td>$virB2_coverage</td><td>$virB2_depth</td></tr>";
				$result_table .= "<tr><td>$virB3_status</td><td>VirB3</td><td>$virB3_coverage</td><td>$virB3_depth</td></tr>";
				$result_table .= "<tr><td>$virB4_status</td><td>VirB4</td><td>$virB4_coverage</td><td>$virB4_depth</td></tr>";
				$result_table .= "<tr><td>$virB5_status</td><td>VirB5</td><td>$virB5_coverage</td><td>$virB5_depth</td></tr>";
				$result_table .= "<tr><td>$virB6_status</td><td>VirB6</td><td>$virB6_coverage</td><td>$virB6_depth</td></tr>";
				$result_table .= "<tr><td>$virB7_status</td><td>VirB7</td><td>$virB7_coverage</td><td>$virB7_depth</td></tr>";
				$result_table .= "<tr><td>$virB8_status</td><td>VirB8</td><td>$virB8_coverage</td><td>$virB8_depth</td></tr>";
				$result_table .= "<tr><td>$virB9_status</td><td>VirB9</td><td>$virB9_coverage</td><td>$virB9_depth</td></tr>";
				$result_table .= "<tr><td>$virB10_status</td><td>VirB10</td><td>$virB10_coverage</td><td>$virB10_depth</td></tr>";
				$result_table .= "<tr><td>$virB11_status</td><td>VirB11</td><td>$virB11_coverage</td><td>$virB11_depth</td></tr>";
				$result_table .= "<tr><td>$virD4_status</td><td>VirD4</td><td>$virD4_coverage</td><td>$virD4_depth</td></tr>";
				$result_table .= "</tbody></table>";
				$result_table .= "</div>";
				$result_table .= "</div>";
				
				#MLSA genes	
				$result_table .= "<div class=\"row\">";
				$result_table .= "<div class=\"span6\">";
				$result_table .= "<table class=\"table table-bordered table-hover\">";
				$result_table .= "<caption><h4>MLSA Genes</h4></caption>";
				$result_table .= "<thead><td>Found</td><td>Gene</td><td>Coverage (%)</td><td>Depth</td></thead>";
				$result_table .= "<tbody><tr><td style=\"width: 50px;\">$recA_status</td><td>recA</td><td>$recA_coverage</td><td>$recA_depth</td></tr>";
				$result_table .= "<tr><td>$glnII_status</td><td>glnII</td><td>$glnII_coverage</td><td>$glnII_depth</td></tr>";
				$result_table .= "<tr><td>$dnaK_status</td><td>dnaK</td><td>$dnaK_coverage</td><td>$dnaK_depth</td></tr>";
				$result_table .= "<tr><td>$rpoB_status</td><td>rpoB</td><td>$rpoB_coverage</td><td>$rpoB_depth</td></tr>";
				$result_table .= "<tr><td>$gyrB_status</td><td>gyrB</td><td>$gyrB_coverage</td><td>$gyrB_depth</td></tr>";
				$result_table .= "<tr><td>$truA_status</td><td>truA</td><td>$truA_coverage</td><td>$truA_depth</td></tr>";
				$result_table .= "<tr><td>$thrA_status</td><td>thrA</td><td>$thrA_coverage</td><td>$thrA_depth</td></tr></tbody></table></div></div><div>";


				
				
				
				#print $result_table;

			} else {
				##Rhodococcus was selected
				
			

                my $output_fh;
				my %gene_hash;
				if( -s $outputfile  ) {
					open($output_fh, $outputfile) || die "failed to read output file: $!";
					my $header = <$output_fh>;
					while (my $line = <$output_fh>) {
						chomp $line;
						my @line = split(/\s+/, $line);
						@{ $gene_hash{$line[2]}  } = @line;
												
					}
					
				}

				my $attR_status = $notfound_img;
				my $attR_coverage = "-";
				my $attR_depth = "-";
				if (exists $gene_hash{"attR"}) {
					$attR_status = $found_img;
					$attR_coverage = @{$gene_hash{"attR"}}[4];
					$attR_depth = @{$gene_hash{"attR"}}[5];	
				}

				my $attX_status = $notfound_img;
				my $attX_coverage = "-";
				my $attX_depth = "-";
				if (exists $gene_hash{"attX"}) {
					$attX_status = $found_img;
					$attX_coverage = @{$gene_hash{"attX"}}[4];
					$attX_depth = @{$gene_hash{"attX"}}[5]; 
				}

				my $attA_status = $notfound_img;
				my $attA_coverage = "-";
				my $attA_depth = "-";
				if (exists $gene_hash{"attA"}) {
					$attA_status = $found_img;
					$attA_coverage = @{$gene_hash{"attA"}}[4];
					$attA_depth = @{$gene_hash{"attA"}}[5];
				}

				my $attB_status = $notfound_img;
				my $attB_coverage = "-";
				my $attB_depth = "-";
				if (exists $gene_hash{"attB"}) {
					$attB_status = $found_img;
					$attB_coverage = @{$gene_hash{"attB"}}[4];
					$attB_depth = @{$gene_hash{"attB"}}[5];
				}

				my $attC_status = $notfound_img;
				my $attC_coverage = "-";
				my $attC_depth = "-";
				if (exists $gene_hash{"attC"}) {
					$attC_status = $found_img;
					$attC_coverage = @{$gene_hash{"attC"}}[4];
					$attC_depth = @{$gene_hash{"attC"}}[5];
				}

				my $attD_status = $notfound_img;
				my $attD_coverage = "-";
				my $attD_depth = "-";
				if (exists $gene_hash{"attD"}) {
					$attD_status = $found_img;
					$attD_coverage = @{$gene_hash{"attD"}}[4];
					$attD_depth = @{$gene_hash{"attD"}}[5];       
				} 

				my $attE_status = $notfound_img;
				my $attE_coverage = "-";
				my $attE_depth = "-";
				if (exists $gene_hash{"attE"}) {
					$attE_status = $found_img;
					$attE_coverage = @{$gene_hash{"attE"}}[4];
					$attE_depth = @{$gene_hash{"attE"}}[5];       
				} 

				my $attF_status = $notfound_img;
				my $attF_coverage = "-";
				my $attF_depth = "-";
				if (exists $gene_hash{"attF"}) {
					$attF_status = $found_img;
					$attF_coverage = @{$gene_hash{"attF"}}[4];
					$attF_depth = @{$gene_hash{"attF"}}[5];       
				} 
				
				my $attG_status = $notfound_img;
				my $attG_coverage = "-";
				my $attG_depth = "-";
				if (exists $gene_hash{"attG"}) {
					$attG_status = $found_img;
					$attG_coverage = @{$gene_hash{"attG"}}[4];
					$attG_depth = @{$gene_hash{"attG"}}[5];       
				} 

				my $attH_status = $notfound_img;
				my $attH_coverage = "-";
				my $attH_depth = "-";
				if (exists $gene_hash{"attH"}) {
					$attH_status = $found_img;
					$attH_coverage = @{$gene_hash{"attH"}}[4];
					$attH_depth = @{$gene_hash{"attH"}}[5];       
				} 
   
   				my $fasA_status = $notfound_img;
		        my $fasA_coverage = "-";
                my $fasA_depth = "-";
				if (exists $gene_hash{"fasA"}) {
					$fasA_status = $found_img;
					$fasA_coverage = @{$gene_hash{"fasA"}}[4];
					$fasA_depth = @{$gene_hash{"fasA"}}[5];       
				}               

				my $fasB_status = $notfound_img;
				my $fasB_coverage = "-";
			    my $fasB_depth = "-";
				if (exists $gene_hash{"fasB"}) {
	  				$fasB_status = $found_img;
					$fasB_coverage = @{$gene_hash{"fasB"}}[4];
					$fasB_depth = @{$gene_hash{"fasB"}}[5];       
				} 

				my $fasC_status = $notfound_img;
				my $fasC_coverage = "-";
		   		my $fasC_depth = "-";
				if (exists $gene_hash{"fasC"}) {
					$fasC_status = $found_img;
					$fasC_coverage = @{$gene_hash{"fasC"}}[4];
					$fasC_depth = @{$gene_hash{"fasC"}}[5];       
				}	

				my $fasD_status = $notfound_img;
                my $fasD_coverage = "-";
				my $fasD_depth = "-";
				if (exists $gene_hash{"fasD"}) {
					$fasD_status = $found_img;
					$fasD_coverage = @{$gene_hash{"fasD"}}[4];
					$fasD_depth = @{$gene_hash{"fasD"}}[5];       
				}

				my $fasE_status = $notfound_img;
				my $fasE_coverage = "-";
				my $fasE_depth = "-";
				if (exists $gene_hash{"fasE"}) {
					$fasE_status = $found_img;
					$fasE_coverage = @{$gene_hash{"fasE"}}[4];
					$fasE_depth = @{$gene_hash{"fasE"}}[5];       
				}

				my $fasF_status = $notfound_img;
				my $fasF_coverage = "-";
				my $fasF_depth = "-";
				if (exists $gene_hash{"fasF"}) {
					$fasF_status = $found_img;
					$fasF_coverage = @{$gene_hash{"fasF"}}[4];
					$fasF_depth = @{$gene_hash{"fasF"}}[5];       
				}

				my $fasR_status = $notfound_img;
				my $fasR_coverage = "-";
				my $fasR_depth = "-";
				if (exists $gene_hash{"fasR"}) {
					$fasR_status = $found_img;
					$fasR_coverage = @{$gene_hash{"fasR"}}[4];
					$fasR_depth = @{$gene_hash{"fasR"}}[5];       
				}

				my $rfa21d2_02304_status = $notfound_img;
				my $rfa21d2_02304_coverage = "-";
				my $rfa21d2_02304_depth = "-";
				if (exists $gene_hash{"fasDF"}) {
					$rfa21d2_02304_status = $found_img;
					$rfa21d2_02304_coverage = @{$gene_hash{"fasDF"}}[4];
					$rfa21d2_02304_depth = @{$gene_hash{"fasDF"}}[5];       
				}

				my $vicA_status = $notfound_img;
				my $vicA_coverage = "-";
				my $vicA_depth = "-";
				if (exists $gene_hash{"vicA"}) {
					$vicA_status = $found_img;
					$vicA_coverage = @{$gene_hash{"vicA"}}[4];
					$vicA_depth = @{$gene_hash{"vicA"}}[5];
				}

				my $ftsY_status = $notfound_img;
				my $ftsY_coverage = "-";
				my $ftsY_depth = "-";
				if (exists $gene_hash{"ftsY"}) {
					$ftsY_status = $found_img;
					$ftsY_coverage = @{$gene_hash{"ftsY"}}[4];
					$ftsY_depth = @{$gene_hash{"ftsY"}}[5];
				}

				my $infB_status = $notfound_img;
				my $infB_coverage = "-";
				my $infB_depth = "-";
				if (exists $gene_hash{"infB"}) {
					$infB_status = $found_img;
					$infB_coverage = @{$gene_hash{"infB"}}[4];
					$infB_depth = @{$gene_hash{"infB"}}[5];
				}

				my $rpoB_status = $notfound_img;
				my $rpoB_coverage = "-";
				my $rpoB_depth = "-";
				if (exists $gene_hash{"rpoB"}) {
					$rpoB_status = $found_img;
					$rpoB_coverage = @{$gene_hash{"rpoB"}}[4];
					$rpoB_depth = @{$gene_hash{"rpoB"}}[5];
				}

				my $rsmA_status = $notfound_img;
				my $rsmA_coverage = "-";
				my $rsmA_depth = "-";
				if (exists $gene_hash{"rsmA"}) {
					$rsmA_status = $found_img;
					$rsmA_coverage = @{$gene_hash{"rsmA"}}[4];
					$rsmA_depth = @{$gene_hash{"rsmA"}}[5];
				}

				my $secY_status = $notfound_img;
				my $secY_coverage = "-";
				my $secY_depth = "-";
				if (exists $gene_hash{"secY"}) {
					$secY_status = $found_img;
					$secY_coverage = @{$gene_hash{"secY"}}[4];
					$secY_depth = @{$gene_hash{"secY"}}[5];
				}

				my $tsaD_status = $notfound_img;
				my $tsaD_coverage = "-";
				my $tsaD_depth = "-";
				if (exists $gene_hash{"tsaD"}) {
					$tsaD_status = $found_img;
					$tsaD_coverage = @{$gene_hash{"tsaD"}}[4];
					$tsaD_depth = @{$gene_hash{"tsaD"}}[5];
				}

				my $ychF_status = $notfound_img;
				my $ychF_coverage = "-";
				my $ychF_depth = "-";
				if (exists $gene_hash{"ychF"}) {
					$ychF_status = $found_img;
					$ychF_coverage = @{$gene_hash{"ychF"}}[4];
					$ychF_depth = @{$gene_hash{"ychF"}}[5];
				}

				#Print results table

				$result_table .= "<em>Rhodococcus fasicans</em> D188 genes were used as reference for all virulence genes except for fasDF, which came from strain A21d2.";	
				$result_table .= "<div class=\"row\">";
                $result_table .= "<div class=\"span6\">";
				$result_table .= "<table class=\"table table-bordered table-hover\">";
				$result_table .= "<caption><h4>att Locus</h4></caption>";
				$result_table .= "<thead><td>Found</td><td>Gene</td><td>Coverage (%)</td><td>Depth</td></thead>";
				$result_table .= "<tbody><tr><td style=\"width: 50px;\">$attR_status</td><td>attR</td><td>$attR_coverage</td><td>$attR_depth</td></tr>";
				$result_table .= "<tr><td>$attX_status</td><td>attX</td><td>$attX_coverage</td><td>$attX_depth</td></tr>";
				$result_table .= "<tr><td>$attA_status</td><td>attA</td><td>$attA_coverage</td><td>$attA_depth</td></tr>";
				$result_table .= "<tr><td>$attB_status</td><td>attB</td><td>$attB_coverage</td><td>$attB_depth</td></tr>";
				$result_table .= "<tr><td>$attC_status</td><td>attC</td><td>$attC_coverage</td><td>$attC_depth</td></tr>";
				$result_table .= "<tr><td>$attD_status</td><td>attD</td><td>$attD_coverage</td><td>$attD_depth</td></tr>";
				$result_table .= "<tr><td>$attE_status</td><td>attE</td><td>$attE_coverage</td><td>$attE_depth</td></tr>";
				$result_table .= "<tr><td>$attF_status</td><td>attF</td><td>$attF_coverage</td><td>$attF_depth</td></tr>";
				$result_table .= "<tr><td>$attG_status</td><td>attG</td><td>$attG_coverage</td><td>$attG_depth</td></tr>";
				$result_table .= "<tr><td>$attH_status</td><td>attH</td><td>$attH_coverage</td><td>$attH_depth</td></tr></tbody></table>";
				$result_table .= "</div>";	
				$result_table .= "<div class=\"span6\">";
				$result_table .= "<table class=\"table table-bordered table-hover\">";
				$result_table .= "<caption><h4>fas Locus</h4></caption>";
				$result_table .= "<thead><td>Found</td><td>Gene</td><td>Coverage (%)</td><td>Depth</td></thead>";
                $result_table .= "<tbody><tr><td style=\"width: 50px;\">$fasR_status</td><td>fasR</td><td>$fasR_coverage</td><td>$fasR_depth</td></tr>";
                $result_table .= "<tr><td>$fasA_status</td><td>fasA</td><td>$fasA_coverage</td><td>$fasA_depth</td></tr>";
                $result_table .= "<tr><td>$fasB_status</td><td>fasB</td><td>$fasB_coverage</td><td>$fasB_depth</td></tr>";
                $result_table .= "<tr><td>$fasC_status</td><td>fasC</td><td>$fasC_coverage</td><td>$fasC_depth</td></tr>";
                $result_table .= "<tr><td>$fasD_status</td><td>fasD</td><td>$fasD_coverage</td><td>$fasD_depth</td></tr>";
				$result_table .= "<tr><td>$fasE_status</td><td>fasE</td><td>$fasE_coverage</td><td>$fasE_depth</td></tr>";
				$result_table .= "<tr><td>$fasF_status</td><td>fasF</td><td>$fasF_coverage</td><td>$fasF_depth</td></tr>";
				$result_table .= "<tr><td>$rfa21d2_02304_status</td><td>RF_A21d2_02304 (fasDF)</td><td>$rfa21d2_02304_coverage</td><td>$rfa21d2_02304_depth</td></tr></tbody></table>";	
				
				$result_table .= "<table class=\"table table-bordered table-hover\">";
				$result_table .= "<caption><h4>vicA</h4></caption>";
				$result_table .= "<thead><td>Found</td><td>Gene</td><td>Coverage (%)</td><td>Depth</td></thead>";
				$result_table .= "<tbody><tr><td style=\"width: 50px;\">$vicA_status</td><td>vicA</td><td>$vicA_coverage</td><td>$vicA_depth</td></tr>";
				$result_table .= "</tbody></table>";	
				$result_table .= "</div>";
				$result_table .= "</div>";

				 $result_table .= "<div class=\"row\">";
				 $result_table .= "<div class=\"span6\">";
				 $result_table .= "<table class=\"table table-bordered table-hover\">";
				 $result_table .= "<caption><h4>MLSA Genes</h4></caption>";
				 $result_table .= "<thead><td>Found</td><td>Gene</td><td>Coverage (%)</td><td>Depth</td></thead>";
				 $result_table .= "<tbody><tr><td style=\"width: 50px;\">$ftsY_status</td><td>ftsY</td><td>$ftsY_coverage</td><td>$ftsY_depth</td></tr>";
				 $result_table .= "<tr><td>$infB_status</td><td>infB</td><td>$infB_coverage</td><td>$infB_depth</td></tr>";
				 $result_table .= "<tr><td>$rpoB_status</td><td>rpoB</td><td>$rpoB_coverage</td><td>$rpoB_depth</td></tr>";
				 $result_table .= "<tr><td>$rsmA_status</td><td>rsmA</td><td>$rsmA_coverage</td><td>$rsmA_depth</td></tr>";
				 $result_table .= "<tr><td>$secY_status</td><td>secY</td><td>$secY_coverage</td><td>$secY_depth</td></tr>";
				 $result_table .= "<tr><td>$tsaD_status</td><td>tsaD</td><td>$tsaD_coverage</td><td>$tsaD_depth</td></tr>";
				 $result_table .= "<tr><td>$ychF_status</td><td>ychF</td><td>$ychF_coverage</td><td>$ychF_depth</td></tr></tbody></table></div></div><div>";
			}
		}
	
	my $html_ending = <<EOF 
	
    </div> <!-- /container -->

    <!-- Le javascript
    ================================================== -->
    <!-- Placed at the end of the document so the pages load faster -->
<script src="http://localhost/~alex/Gall-ID/Bootstrap_files/jquery.js"></script>
	<script src="http://localhost/~alex/Gall-ID/Bootstrap_files/bootstrap-transition.js"></script>
	<script src="http://localhost/~alex/Gall-ID/Bootstrap_files/bootstrap-alert.js"></script>
	<script src="http://localhost/~alex/Gall-ID/Bootstrap_files/bootstrap-modal.js"></script>
	<script src="http://localhost/~alex/Gall-ID/Bootstrap_files/bootstrap-dropdown.js"></script>
	<script src="http://localhost/~alex/Gall-ID/Bootstrap_files/bootstrap-scrollspy.js"></script>
	<script src="http://localhost/~alex/Gall-ID/Bootstrap_files/bootstrap-tab.js"></script>
	<script src="http://localhost/~alex/Gall-ID/Bootstrap_files/bootstrap-tooltip.js"></script>
	<script src="http://localhost/~alex/Gall-ID/Bootstrap_files/bootstrap-popover.js"></script>
	<script type="text/javascript" src="http://jzaefferer.github.com/jquery-validation/jquery.validate.js"></script>
 </body>
      <footer class="footer">
      <div class="row-fluid">
 		<p> Add some text here <p>
     </div>
      </footer>
      </html>
EOF
;
#print $html_ending;

	open(LOCAL, ">$datadir_prefix/tmp/$jobfile_prefix/index.html") or die $!;
	print LOCAL $html_template_beginning;
	print LOCAL $result_table;
	print LOCAL $html_ending;
	close(LOCAL);
}
