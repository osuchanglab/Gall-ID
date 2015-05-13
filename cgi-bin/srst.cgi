#!/usr/bin/perl -wT

use strict;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use Email::Valid;
use Email::Send;
use Email::Simple::Creator;
use Email::Send::Gmail;
use File::Basename;

#use CGI.pm module
my $q=new CGI;
$CGI::POST_MAX = 1024 * 40000; #Set limit to 4GB per post

#Secure ENV path for perl tainted mode (-T)
delete @ENV{'PATH', 'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};


my $OK_CHARS='-a-zA-Z0-9_.@';	# A restrictive list for sanitizing input
my $safe_filename_characters = "a-zA-Z0-9_.-";

my $jobname=$q->param('jobname');
my $read_one_name=$q->param('read_one');
my $read_two_name=$q->param('read_two');
my $organism=$q->param('organism');
my $min_cov=$q->param('min_cov');
my $max_divergence=$q->param('max_divergence');
$jobname  =~ s/[^$OK_CHARS]/_/go;
if ( $jobname =~ /^([$OK_CHARS]+)$/ ) 
{
            $jobname = $1;
}
$min_cov =~ s/[^0-9]//go;
if ( $min_cov =~ /^([0-9]+)$/ )                                   
{
            $min_cov = $1;
}
$max_divergence =~ s/[^0-9]//go;
if ( $max_divergence =~ /^([0-9]+)$/ )                                   
{
            $max_divergence = $1;
}
$organism =~ s/[^$OK_CHARS]/_/go;
if ( $organism =~ /^([$OK_CHARS]+)$/ )                                   
{
            $organism = $1;
}
#my $jobname = $jobname_unsan;

my $email=$q->param('email');
($email) = $email =~ /(.*)/;


#Not perfect, should change to get timestamp in milliseconds
my $jobfile_prefix = 'job_' . time(). '_' . int(rand(9999)) . '';

my $datadir_prefix = '/Users/alex/Sites/Gall-ID/files';

my $virdb;
if($organism eq "Agrobacterium") {
	$virdb="agrovirdb";
} else {
	#use Rhodococcus db
	$virdb="rhodovirdb";
}
#get the parameter from name field
# and store in $value variable.

#open (FASTA, ">query.fasta") or die ("Could not open file");
#print FASTA $fasta;
#close FASTA;
print $q->header;
&html;

#my $results_email = Email::Simple->create(
#	header => [
#		To		=>	$email,
#		From	=>	'"Chang Lab" <osu.chang@gmail.com>',
#		Subject	=>  "GALL-ID Virulence Gene ID results for $jobname",
#	],	
#	body => "Your recently submitted job $jobname has completed. You can view the results of the analysis here:\nhttp://localhost/~alex/Gall-ID/files/tmp/$jobfile_prefix/index.html\n\nThe results of the analysis will be available for 7 days before being deleted. Thank you for using this service. Do not reply to this message.\n",
#);

#my $email_sender = Email::Send->new(
#{	mailer		=> 'Gmail',
#	mailer_args => [
#		username => 'osu.chang',
#		password => 'effector1',
#	]
#}
#);
#eval { $email_sender->send($results_email) };
#die "Error sending email: $@" if $@;



#Run SRST and make the output index file.
sub html{

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
	<strong>Forward/Single reads file:</strong> $read_one_name<br>
	<strong>Reverse reads file:</strong> $read_two_name<br>
	<strong>Minimum % coverage of database gene:</strong> $min_cov%<br>
	<strong>Maximum % divergence from database gene:</strong> $max_divergence%<br>
	<strong>Output file prefix:</strong> $jobfile_prefix<br>
	<strong>Email:</strong> $email<br>
	</p>
	<hr></hr>
EOF
;
##########
print $html_template_beginning;


my $result_table;

#### Check email address #####
my $is_valid_email = Email::Valid->address($email);
if (! $is_valid_email) {
	print "Please enter a valid email address to receive the results of this program.<br>";
} else {
	#Valid email, now upload files and check they are correct

	my $read_one_filename;
	my $read_two_filename;		

	#Make job results folder in tmp
	my $jobdir = "$datadir_prefix/tmp/$jobfile_prefix";
	unless(mkdir $jobdir) {
    	die "Unable to create $jobdir";
    }

	#Process forward read file, must exist
		
	if ( !$read_one_name )
	{
		print "There was a problem uploading your read file (try a smaller file).";
		exit;
	}
	my ( $name, $path, $extension ) = fileparse ( $read_one_name, '..*' );
	$read_one_filename = $name . $extension;
	$read_one_filename =~ tr/ /_/;
	$read_one_filename =~ s/[^$safe_filename_characters]//go;
	if ( $read_one_filename =~ /^([$safe_filename_characters]+)$/ )
	{
		$read_one_filename = $1;
	}
	else
	{
		die "Filename contains invalid characters";
	}
	my $read_one_filehandle = $q->upload("read_one");
	open(LOCAL, ">$datadir_prefix/tmp/$jobfile_prefix/read_1.fastq") or die $!;
	binmode LOCAL;
	while(<$read_one_filehandle>) {
	    print LOCAL;
	}
	close(LOCAL);
	if (!($read_two_name eq "")) {
		my ( $name, $path, $extension ) = fileparse ( $read_two_name, '..*' );
    	$read_two_filename = $name . $extension;
  		$read_two_filename =~ tr/ /_/;
    	$read_two_filename =~ s/[^$safe_filename_characters]//go;
    	if ( $read_two_filename =~ /^([$safe_filename_characters]+)$/ )
    	{
    	    $read_two_filename = $1;
    	}
    	else
    	{
    	    die "Filename contains invalid characters";
    	}
		if ($read_two_filename eq $read_one_filename) {
			$read_two_filename = $read_two_filename . "_2.fastq";
		}
		my $read_two_filehandle = $q->upload("read_two");
		open(LOCAL, ">$datadir_prefix/tmp/$jobfile_prefix/read_2.fastq") or die $!;
    	binmode LOCAL;
		while(<$read_two_filehandle>) {
        	print LOCAL;
    	}
		close(LOCAL);
	} else {
		$read_two_filename = "";
	}
	

	#Run SRST2
	my $readtwofilevar = $read_two_filename;
	if ($readtwofilevar eq "") {
		$readtwofilevar = "NONE";
	}

	#Run the run_srst_job.pl command to run SRST in the background
	my $pid = fork;
	die "Fork failed: $!" unless defined $pid;
	unless($pid) {
		exec("/Library/WebServer/CGI-Executables/run_srst_job.pl $jobname $organism $email $datadir_prefix $jobfile_prefix $virdb $read_one_filename $readtwofilevar $min_cov $max_divergence &> $datadir_prefix/tmp/$jobfile_prefix/joboutput.txt &");
		die("Exec failed: $!\n");
	}
		print "<h4 class=\"text-info\">Your job has been submitted. You will receive an email at $email once it completes with a link to the results page. Thank you!</h4>";
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
print $html_ending;

;}
;
