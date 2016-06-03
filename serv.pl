use strict;
use threads;
use IO::Socket::INET;

$| ++;

my $listener = IO::Socket::INET->new(LocalPort => 4992,
                                     Listen => 5,
                                     Reuse => 1) || 
             die "Cannot create socket\n";

my $client;
my $client_num = 0;
while (1) {
   $client = $listener->accept;
   threads->create(\&start_thread, $client, ++ $client_num);
}

sub split_commands
{
    my $cmd_buffer = shift @_;
    my @cmds = split(/[\r\n]/,$cmd_buffer);
    return @cmds;
}

sub do_command 
{
    my $client = shift @_;
    my $cmdline = shift @_;
    # http://wiki.flexradio.com/index.php?title=SmartSDR_TCP/IP_API
    # C[D]<seq_number>|command<terminator>
    # look for command like C22|profile display info
    if ($cmdline =~ /(C)(D?)(\d+)\|(.*)/) 
    {  
	my $cee = $1;
	my $debug = $2;
	my $seq = $3;
	my $cmd = $4;
	# print ("Command is $4; Debug? $2; sequence $3\n");
	# https://community.flexradio.com/flexradio/topics/what_are_the_command_response_codes_for_the_network_api
	my $response = "R$seq|0||OK\n";
	print "-> $response";
	print $client $response;
    }
}

sub start_thread {
   threads->self->detach();
   my ($client, $client_num) = @_;
   print "thread created for client $client_num\n";
   while (1) {
       my $whole_req = "";
       do {
           my $req;
           $client->recv($req, 700000);
           return if ($req eq ""); 
           $whole_req = $whole_req . $req;
	   print "so far: $whole_req\n";
	   print "unpack ".unpack("H*",$whole_req);
       } until ($whole_req =~ m/\n/x);
       #print "client $client_num got req:\n$whole_req";
       
       my @cmds = split_commands($whole_req);
       foreach my $cmd (@cmds) {
	   printf ("<- $cmd\n");
	   do_command($client,$cmd);
       }
      #$whole_req =~ m/Host: ([\.|\w]*)/;
       #my $host = $1;
       #my $server = new IO::Socket::INET(Proto => "tcp",
       #                                  PeerPort => 80,
       #                                  PeerAddr => $host) ||
       #             die "failed to connect to $host\n";
       #print $server $whole_req;
       #my $whole_res = "";
       #do {
       #    my $res;
       #    $server->recv($res, 700000);
       #    $whole_res = $whole_res . $res;
       #} until ($whole_res =~ m/<\/html>/);
       #print "client $client_num got res\n";
       #print $client $whole_res;
       #close($server);
   }
   return;
}
