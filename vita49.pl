#!/usr/bin/perl -w
# Vita-49 Discovery Packet broadcaster, so the Antenna Genius can find us. We act like a FlexRadio. 

use IO::Socket;
use strict;

use constant {
 # see http://www.ice-online.com/support/documentation/ice-vita-49-0-radio-transport-ethernet-packet-specification/#ICE_VRT_Packet_.E2.80.93_Header   
 # and http://www.wdv.com/Electronics/Reference/SDROoverWEB-VITA.pdf

    VITA_PACKET_TYPE_EXT_DATA_WITH_STREAM_ID => 0b0011 << 28,
    VITA_HEADER_CLASS_ID_PRESENT => 1 << 27,
    VITA_TSI_OTHER => 0b11 << 22,
    VITA_TSI_NONE => 0b00 << 22,
    VITA_TSF_SAMPLE_COUNT => 0b01 << 20,
    VITA_TSF_NONE => 0b00 << 20,
    VITA_MAX_DISCOVERY_PAYLOAD_SIZE => 1440-32   # see http://www.ice-online.com/support/documentation/ice-vita-49-0-radio-transport-ethernet-packet-specification/ 
};

sub roundup {
    my $number = shift @_;
    my $multiple = shift @_;
    my $remainder = $number % $multiple;
    return $number if (($multiple == 0) || ($remainder == 0));
    return $number + $multiple - $remainder;
}

sub vita49_discovery_packet {

    my $packet_count = shift @_;
    my $packet_len_words = shift @_;
    my $stream_id = shift @_;
    my $class_id_h = shift @_;
    my $class_id_l = shift @_;
    my $payload = shift @_;

    my $payload_len = length($payload)+1;
    my $payload_len = roundup($payload_len, 4);

    $packet_len_words = $payload_len / 4 + 7;  # ( 28 bytes of header + payload_len ) / 4
    my $header = 
     VITA_PACKET_TYPE_EXT_DATA_WITH_STREAM_ID |
     VITA_HEADER_CLASS_ID_PRESENT |
     VITA_TSI_OTHER |
     VITA_TSF_SAMPLE_COUNT |
     (($packet_count++ & 0xF) << 16) |
     ($packet_len_words & 0xFFFF);

    my $timestamp_int = 0;
    my $timestamp_frac_h = 0;
    my $timestamp_frac_l = 0;

    # for a discovery packet, 
    # 0x800 is the stream_id
    # 0x543CFFFF is the class_id;

    my $vita_max = VITA_MAX_DISCOVERY_PAYLOAD_SIZE;
    return pack("NNNNNNNZ[$payload_len]",$header, $stream_id, $class_id_h, $class_id_l, $timestamp_int, $timestamp_frac_h, $timestamp_frac_l, $payload);
}

sub payload_string() {
    # model=%s serial=%s version=%s name=%s callsign=%s ip=%u.%u.%u.%u port=%u 
    # return("model=Elecraft_K3 serial=00512 version=0010 name=main_k3 callsign=n9adg ip=192.168.1.1 port=3702");
    # return("discovery_protocol_version=2.0.0.0 model=FLEX-6500 serial=2514-3157-6500-1623 version=1.3.8.47 nickname=HB9EYQ_6500 callsign=HB9EYQ ip=192.168.88.49 port=4992 status=Available");
    return("discovery_protocol_version=2.0.0.0 model=Elecraft-K3 serial=0512 version=1.0 nickname=N9ADG_K3_MULT callsign=N9ADG ip=192.168.88.49 port=4992 status=Available");
}


my($sock,  $packet_count, $packet_length_words,
   $port, $ipaddr, $hishost,$iaddr);

my $PORTNO  = 4992;
my $server_host = '192.168.88.255';
my $TIMEOUT = 5;
my $packet_length_words = 7+VITA_MAX_DISCOVERY_PAYLOAD_SIZE/4;
my $packet_count = 0;
my $bcast_socket = IO::Socket::INET->new(Proto     => 'udp',
				  PeerPort  => 4992, #
				  PeerAddr  => $server_host,
				  Type  => SOCK_DGRAM,
				  Broadcast => 1)
    or die "Creating socket: $!\n";

while(1) {

    my $msg         = vita49_discovery_packet($packet_count, $packet_length_words, 0x800, 0x1c2d, 0x534CFFFF, payload_string());

    printf("PACKET: %s\n",unpack("H*",$msg));

    $bcast_socket->send($msg) or die "send: $!";
    $packet_count++;
    sleep(3);
}


