#!/usr/bin/perl

use IO::Socket::INET;
use Switch;
use Expect;

my $default_pianobar_station=1;
my $station_list;

# auto-flush on socket
$| = 1;

# creating a listening socket
my $socket = new IO::Socket::INET (
  LocalHost => '0.0.0.0',
  LocalPort => '7777',
  Proto => 'tcp',
  Listen => 5,
  Reuse => 1
);

die "cannot create socket $!\n" unless $socket;
print "server waiting for client connection on port 7777\n";

my $exp; #--- control for Expect Program
my $client_socket;


main_server();

sub main_server()
{
  print ("Running Main Server\n");
  while(1)
  {
    # waiting for a new client connection
    $client_socket = $socket->accept();

    # get information about a newly connected client
    my $client_address = $client_socket->peerhost();
    my $client_port = $client_socket->peerport();
    print "connection from $client_address:$client_port\n";

    # read up to 1024 characters from the connected client
    my $data = "";
    $client_socket->recv($data, 1024);

    my $command;
    my $parameter;
 
    $data=~ s/\R//;
    ($command,$parameter)=split(/[ ]+/,$data);

    print "received data: '".$data."'\n";

    switch ($command)
    {
      case "start"
      {
        pianobar_start();
   
        #--- check if station is a number, if not pass default station
        if ($parameter =~ /[0-9]+$/ )
        {
          pianobar_play($parameter);
        }
        else
        {
          pianobar_play($default_pianobar_station);
        }
        pianobar_list();
      }
  
      case "select"
      {
        pianobar_select(); 
        pianobar_play($parameter);
      }
  
      case "stop"
      {
        print ("Closing");
        $exp->send("q");
        $exp->soft_close();
        print ("Closed");
      }
  
      case "list"
      {
        pianobar_list();
      }
  
      case "info"
      {
        pianobar_info();
      }
  
      case "next"
      {
        pianobar_next();
      }
      else 
      {
        print ("Unknown Command\n");
      }
    }; 
    # write response data to the connected client
    shutdown($client_socket, 1);
 
  }
} #--- end main server sub

sub pianobar_start()
{
  #--- make sure pianobar isn't already running
  if (`pidof pianobar`)
  {
    #$client_socket->send("already started\n");
    #--- its running
    return;
  }

  $exp = Expect->spawn("pianobar")
    or die "Cannot spawn pianobar: $!\n";;

  print ("Pianobar is running\n");
}

sub pianobar_play()
{
  $station=$_[0];
  my $output;
  #--- get to stations list
  $exp->expect($timeout,
    [
      '0\)',
      sub {
      }
    ],
    [
      timeout =>
      sub {
        die "Timed out.\n";
      }
    ]
  );
  #--- Read up to Select station, capture stations
  $exp->expect($timeout,
    [
      '\[\?\] Select station:',
      sub {
        $spawn_ok = 1;
        my $fh = shift;
        $output = $fh->exp_before;
        #--- play station
        $fh->send($station."\n");
        print ("Playing station $station\n");
      }
    ],
    [
       eof =>
       sub {
         if ($spawn_ok) {
           die "Never prompted for station.\n";
         } else {
           die "Never prompted for station.\n";
         }
       } #--- end sub
    ],
    [
      timeout =>
      sub {
        die "Timed out.\n";
      }
    ]
  );
  #--- put the 0 back in
  $output="0) ".$output;
  my @output_array=split(/\n/,$output);
  $station_list="";
  foreach (@output_array) {
    my $station_num;
    my $station_name;
    ($station_num,$station_name)=split (/\)[ qQ]+[ ]*/,$_);
   
    $station_num =~ s/^\s+|\s+|t+$//g;
    $station_name =~ s/^\s+|\s+|t+$//g;

    #--- only add if number
    if ($station_num =~ /[0-9]+$/ )
    {
      $station_list=$station_list.$station_num.";".$station_name."\n";
    }
  }
 
}
 

sub pianobar_list()
{
  $client_socket->send($station_list); 
}

sub pianobar_select()
{
  $exp->send("s");
}

sub pianobar_next()
{
  $exp->send("n");
  $exp->clear_accum();
}

sub pianobar_info()
{
  my $output;
  $exp->send("i");
  $exp->expect($timeout,
    [
      '#',
      sub {
        $spawn_ok = 1;
        my $fh = shift;
        $output = $fh->exp_before;
      }
    ]
  );
  $exp->clear_accum();
  $client_socket->send($output);
}

