#!/usr/bin/env perl

use strict;
use warnings;

### This is how you can tell where MYHADOOP_HOME is from Perl
use Cwd 'abs_path';
my $mh_config;
$mh_config{'home'} = abs_path($0);

################################################################################
# merge_xml( old_config.xml, hashref to new_config_hash ) - merge the values in 
#   new_config_hash into the contents of old_config.xml and write out the 
#   resulting hash
################################################################################
sub merge_xml {
    use XML::Simple;
    use Data::Dumper;

    my $input_xml = shift;
    my $new_config = shift;

    my $xml = XML::Simple->new();

    my $config = $xml->XMLin($input_xml, (
        KeyAttr => 'name', 
        KeepRoot => 1,
        ));

    ### Do the merge and overwrite $%config's values with $%new_config's
    @config{ keys( %$new_config ) } = values( $%new_config );

    ### We need to undo the effects of calling XMLin with KeyAttr => 'name'
    ### without creating a bunch of attributes for cosmetic purposes
    my $newlist;
    foreach my $key ( keys(%{$config->{configuration}->{property}}) )
    {
        my $new_property;
        $new_property = $config->{configuration}->{property}->{$key};
        $new_property->{name} = $key;
        push( @$newlist, $new_property );
    }
    $config->{configuration}->{property} = $newlist;

    ### Dump out without attributes
    return $xml->XMLout($config, ( 
        NoAttr => 1,
        RootName => undef, 
        XMLDecl => '<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>' ,
        ));
}
