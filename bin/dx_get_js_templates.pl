#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright (c) 2016 by Delphix. All rights reserved.
#
# Program Name : dx_get_js_templates.pl
# Description  : Get Delphix Engine timeflow bookmarks
# Author       : Marcin Przepiorowski
# Created      : 02 Mar 2016 (v2.2.3)
#

use strict;
use warnings;
use JSON;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev); #avoids conflicts with ex host and help
use File::Basename;
use Pod::Usage;
use FindBin;
use Data::Dumper;

my $abspath = $FindBin::Bin;

use lib '../lib';
use Engine;
use Formater;
use Toolkit_helpers;
use JS_template_obj;
use Databases;


my $version = $Toolkit_helpers::version;


GetOptions(
  'help|?' => \(my $help),
  'd|engine=s' => \(my $dx_host),
  'template_name=s' => \(my $template_name),
  'property_name=s' => \(my $property_name),
  'properties' => \(my $properties),
  'backup=s' => (\my $backup),
  'format=s' => \(my $format),
  'all' => (\my $all),
  'version' => \(my $print_version),
  'dever=s' => \(my $dever),
  'nohead' => \(my $nohead),
  'debug:i' => \(my $debug),
  'configfile|c=s' => \(my $config_file)
) or pod2usage(-verbose => 1,  -input=>\*DATA);

pod2usage(-verbose => 2,  -input=>\*DATA) && exit if $help;
die  "$version\n" if $print_version;

my $engine_obj = new Engine ($dever, $debug);
$engine_obj->load_config($config_file);


if (defined($all) && defined($dx_host)) {
  print "Option all (-all) and engine (-d|engine) are mutually exclusive \n";
  pod2usage(-verbose => 1,  -input=>\*DATA);
  exit (1);
}


# this array will have all engines to go through (if -d is specified it will be only one engine)
my $engine_list = Toolkit_helpers::get_engine_list($all, $dx_host, $engine_obj);
my $output = new Formater();

if (defined($backup)) {
  if (! -d $backup) {
    print "Path $backup is not a directory \n";
    exit (1);
  }
  if (! -w $backup) {
    print "Path $backup is not writtable \n";
    exit (1);
  }
  $output->addHeader(
      {'Paramters', 200}
  );
} elsif (defined($properties) || defined($property_name)) {
  $output->addHeader(
      {'Appliance',       20},
      {'Template name',   20},
      {'Property name',  20},
      {'Property value', 20},
  );
} else {
  $output->addHeader(
      {'Appliance',   20},
      {'Template name', 20},
  );
}

my $ret = 0;

for my $engine ( sort (@{$engine_list}) ) {
  # main loop for all work
  if ($engine_obj->dlpx_connect($engine)) {
    print "Can't connect to Dephix Engine $dx_host\n\n";
    $ret = $ret + 1;
    next;
  };


  my $jstemplates = new JS_template_obj ($engine_obj, $debug );

  my $db;
  my $groups;
  if (defined($backup)) {
    $db = new Databases ( $engine_obj , $debug);
    $groups = new Group_obj($engine_obj, $debug);
  }


  my @template_array;


  if (defined($template_name)) {
    my $temp = $jstemplates->getJSTemplateByName($template_name);
    if (defined($temp)) {
      push(@template_array, $temp);
    } else {
      print "Template not found\n";
      $ret = $ret + 1;
      next;
    }
  } else {
    @template_array = @{$jstemplates->getJSTemplateList()};
  }



  for my $jstitem (@template_array) {

    if (defined($properties) || defined($property_name)) {

      my %prophash = %{$jstemplates->getProperties($jstitem)} ;

      if (defined($property_name)) {
        if ( defined($prophash{$property_name}) ) {
          $output->addLine(
              $engine,
              $jstemplates->getName($jstitem),
              $property_name,
              $prophash{$property_name}
            );
        }

      } else {

        for my $propitem ( sort ( keys %prophash ) ) {
          $output->addLine(
              $engine,
              $jstemplates->getName($jstitem),
              $propitem,
              $prophash{$propitem}
            );
        }

      }

    } elsif (defined($backup)) {
      # for backup

      $jstemplates->generateBackup($engine_obj, $jstitem, $db, $groups, $output);

    } else {
      $output->addLine(
          $engine,
          $jstemplates->getName($jstitem)
        );
    }

  }

}

if (defined($backup)) {

  if ($ret eq 0) {
    my $FD;
    my $filename = File::Spec->catfile($backup,'backup_selfservice_templates.txt');

    if ( open($FD,'>', $filename) ) {
      $output->savecsv(1,$FD);
      print "Backup exported into $filename \n";
    } else {
      print "Can't create a backup file $filename \n";
      $ret = $ret + 1;
    }
    close ($FD);
  }

} else {
    Toolkit_helpers::print_output($output, $format, $nohead);
}


exit $ret;

__DATA__

=head1 SYNOPSIS

 dx_get_js_templates    [ -engine|d <delphix identifier> | -all ]
                        [ -configfile file ]
                        [-template_name template_name]
                        [-properties]
                        [-property_name property_name]
                        [-backup path]
                        [ -format csv|json ]
                        [ --help|? ] [ -debug ]

=head1 DESCRIPTION

Get the list of Jet Stream templates from Delphix Engine.

=head1 ARGUMENTS

Delphix Engine selection - if not specified a default host(s) from dxtools.conf will be used.

=over 10

=item B<-engine|d>
Specify Delphix Engine name from dxtools.conf file

=item B<-all>
Display databases on all Delphix appliance

=item B<-configfile file>
Location of the configuration file.
A config file search order is as follow:
- configfile parameter
- DXTOOLKIT_CONF variable
- dxtools.conf from dxtoolkit location

=back

=head2 Options

=over 4

=item B<-template_name template_name>
Display template with a template_name

=item B<-properties>
Display properties from templates

=item B<-property_name property_name>
Display property property_name from template

=item B<-backup path>
Gnerate a dxToolkit commands to recreate templates

=item B<-format>
Display output in csv or json format
If not specified pretty formatting is used.

=item B<-help>
Print this screen

=item B<-debug>
Turn on debugging

=item B<-nohead>
Turn off header output

=back

=head1 EXAMPLES

List templates

 dx_get_js_templates -d Landshark5

 Appliance            Template name
 -------------------- --------------------
 Landshark5           test

List templates with properties

 dx_get_js_templates -d Landshark5 -properties

 Appliance            Template name        Property name        Property value
 -------------------- -------------------- -------------------- --------------------
 Landshark5           test                 prop1                value

 Backup templates configuration

  dx_get_js_containers -d marcindlpx -backup /tmp
  Backup exported into /tmp/backup_selfservice_templates.txt


=cut
