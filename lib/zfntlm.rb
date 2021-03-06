#!/usr/bin/env ruby
#encoding: ASCII-8BIT
=begin
poc to decode ntlm responses
=end
domain = "TESTDOM2K8"
#puts domain.upcase().unpack("C*").pack('v*').unpack('H*')
#puts [domain.upcase().unpack("C*").pack('v*').length].pack('v').unpack('H*')

module ZFNtlm
  class Message
    attr_accessor :type, :domain, :username, :lmhash, :ntlmhash,:hostname
    def initialize (msg="")
      @msg = msg
      if msg[0..7] != "\x4e\x54\x4c\x4d\x53\x53\x50\x00" then return false end
      if msg[8..11] == "\x01\x00\x00\x00" then @type = 1
      elsif msg[8..11] == "\x02\x00\x00\x00" then @type = 2
      elsif msg[8..11] == "\x03\x00\x00\x00" then @type = 3
      else return false end
    end
    def parsetype3(msg = @msg)
      if msg[0..7] != "\x4e\x54\x4c\x4d\x53\x53\x50\x00" then return false end
      if msg[8..11] != "\x03\x00\x00\x00" then return false end 
      @type = 3
      lmlen = msg[12,2].unpack("S*")[0]
      lmoffset = msg[16,4].unpack("L*")[0]
      ntlmlen = msg[20,2].unpack("S*")[0]
      ntlmoffset = msg[24,4].unpack("L*")[0]
      domainnamelen = msg[28,2].unpack("S*")[0]
      domainnameoffset = msg[32,4].unpack("L*")[0]
      usernamelen = msg[36,2].unpack("S*")[0]
      usernameoffset = msg[40,4].unpack("L*")[0]
      hostnamelen = msg[44,2].unpack("S*")[0]
      hostnameoffset = msg[48,4].unpack("L*")[0]
      sessionkeylen = msg[52,2].unpack("S*")[0]
      sessionkeyoffset = msg[56,4].unpack("L*")[0]
      @flags = msg[60,4]
      @version = msg[64,8]
      @mic = msg[72,16]
      @domain = msg[domainnameoffset,domainnamelen].unpack("v*").map{|c|c.chr}.join
      @username = msg[usernameoffset,usernamelen].unpack("v*").map{|c|c.chr}.join
      @lmhash =  msg[lmoffset,lmlen]
      @ntlmhash = msg[ntlmoffset,ntlmlen]
      @hostname = msg[hostnameoffset,hostnamelen].unpack("v*").map{|c|c.chr}.join
      @sessionkey = msg[sessionkeyoffset,sessionkeylen]
      
    end
    
    def buildtype3()
      domainname = @domain
      flgs = @flags
      username = @username
      hostname = @hostname
      sessionkey = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
      sessionkey = @sessionkey
      mic = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
      
      if @ntlmhash.length > 64 then #type2 msg find actual length
        @ntlmhmac = @ntlmhash[0,16]
        @ntlmheader = @ntlmhash[16,4]
        @ntlmreserved = @ntlmhash[20,4]
        @ntlmtime = @ntlmhash[24,8]
        @ntlmclientchal = @ntlmhash[32,8]
        @ntlmunknown = @ntlmhash[40,4]
        pos = 44
        ntlmhash = @ntlmhash[0,44]
        while pos < @ntlmhash.length
          type = @ntlmhash[pos,2]
          len = @ntlmhash[pos+2,2].unpack("S")[0]
          if type == "\x08\x00" || type == "\x0a\x00" || type == "\x09\x00" || type == "\x06\x00" then
          else

            ntlmhash = ntlmhash + @ntlmhash[pos,4+len]
            
            
          end
          pos = pos + len + 4
        end
        
      end
      
      
      packet =  "\x4e\x54\x4c\x4d\x53\x53\x50\x00" + # NTLMSSP
                "\x03\x00\x00\x00" + # MSG Type 2
                [@lmhash.length].pack('v') + #
                [@lmhash.length].pack('v') + #  
                [(88+username.length+domainname.length+hostname.length)].pack('L') + # UPDATE
                [ntlmhash.length].pack('v') + #
                [ntlmhash.length].pack('v') + #
                [(88+username.length+domainname.length+hostname.length+lmhash.length)].pack('L') + # UPDATE
                [domainname.length].pack('v') + # Domain Name Length
                [domainname.length].pack('v') + # Domain Name Max Len
                [88].pack("L") + # Domain Name Offset with 88 static size of header
                [username.length].pack('v') +
                [username.length].pack('v') + 
                [(88+domainname.length)].pack("L") + #
                [hostname.length].pack('v') +
                [hostname.length].pack('v') +
                [(88+username.length+domainname.length)].pack('L') +
                [sessionkey.length].pack('v') + 
                [sessionkey.length].pack('v') + 
                [(88+username.length+domainname.length+hostname.length+@lmhash.length+ntlmhash.length)].pack('L') +
                @flags + # 4 bytes
                "\x06\x01\xb0\x1d\x00\x00\x00\x0f" + # NTLM Version 6.1 15 8 bytes
                mic + # 8 bytes
                domainname + 
                username + 
                hostname + 
                @lmhash + 
                ntlmhash + 
                sessionkey
                return packet
    end
    def buildtype2(chal="\x11\x22\x33\x44\x55\x66\x77\x88",domainname="DOMAIN",hostname="HOSTNAME",domaindnsname="DOMAIN.TLD",serverdnsname="SERVER.DOMAIN.TLD")
      
      domainname = domainname.upcase.unpack("U*").pack("S*")
      hostname = hostname.upcase.unpack("U*").pack("S*")
      domaindnsname = domaindnsname.upcase.unpack("U*").pack("S*")
      serverdnsname = serverdnsname.upcase.unpack("U*").pack("S*")
      #flags = "\x15\x82\x89\x62" #TODO Add flag generation
      flags = "\x15\x82\x81\x62" #TODO Add flag generation
      @addresslist =  "\x02\x00" + # Item - NetBios Domain Name
                      [domainname.length].pack('v') + # Item Length
                      domainname + # Domain Name (DOMAIN)
                      "\x01\x00" + # Item - Net Bios Hostname
                      [hostname.length].pack('v') + # Item Length
                      hostname + # Hostname (HOSTNAME)
                      "\x04\x00" + # Item Dns Domain Name
                      [domaindnsname.length].pack('v') + # Item Length
                      domaindnsname + # DNS Domain Name (domain.tld)
                      "\x03\x00" + # DNS Host Name
                      [serverdnsname.length].pack('v') + # Length
                      serverdnsname + 
                      "\x00\x00\x00\x00" # End of List + 0 Length
      
      @default =  "\x4e\x54\x4c\x4d\x53\x53\x50\x00" + # NTLMSSP
                  "\x02\x00\x00\x00" + # MSG Type 2
                  [domainname.length].pack('v') + # Domain Name Length
                  [domainname.length].pack('v') + # Domain Name Max Len
                  [56].pack("L") + # Domain Name Offset with 56 static size of header
                  flags + # 4 bytes
                  chal + # 8 bytes
                  "\x00\x00\x00\x00\x00\x00\x00\x00" + # Reserved? 8 bytes
                  [@addresslist.length].pack('v') + # Address List Length 2 bytes
                  [@addresslist.length].pack('v') + #Address List Maxlen 2 bytes
                  [(56+domainname.length)].pack("L") + # Address List Offset 4 bytes
                  "\x06\x01\xb0\x1d\x00\x00\x00\x0f" + # NTLM Version 6.1 15 8 bytes
                  domainname + 
                  @addresslist
      return @default
    end
  end
end


#a = ZFNtlm::Message.new()
#a.buildtype2()

class NTLMType2
 
  @type2data = ""
  def initialize(type2msg = "")
    @type2data = type2msg
  end
  def setdomain(domain)
    #puts domain.upcase().unpack("C*").pack('v*').unpack('H*')
    #puts [domain.upcase().unpack("C*").pack('v*').length].pack('v').unpack('H*')
  end
  def get()
    #return "\x4e\x54\x4c\x4d\x53\x53\x50\x00" + [@domain.length].pack("v") + [@domain.length].pack("v") + [(@domain.length + 30)].pack("v") + @chal + "\x00\x00\x00\x00\x00\x00\x00\x00"
    return "TlRMTVNTUAACAAAADAAMADAAAAAHAgOiESIzRFVmd4gAAAAAAAAAAGIAYgA8AAAARABPAE0AQQBJAE4AAgAMAEQATwBNAEEASQBOAAEADABTAEUAUgBWAEUAUgAEABYAZQB4AGEAbQBwAGwAZQAuAGMAbwBtAAMAJABTAEUAUgBWAEUAUgAuAGUAeABhAG0AcABsAGUALgBjAG8AbQAAAAAA"
  end
end

class NTLMType3
  def initialize(type3msg = "something")
    @t3msg = type3msg
    if (@t3msg[0,8] != "\x4e\x54\x4c\x4d\x53\x53\x50\x00") then raise "Type3 - Not NTLMSSP" end
    
  end
  
  rescue NTLMType3::Error
    puts "FAIL"
end

#a = NTLMType3.new

#require './poc_relay_smb_ews_constants'

#test2 = '4e544c4d5353500003000000180018008a0000007e017e01a200000014001400580000000c000c006c00000012001200780000001000100020020000150288e20601b01d0000000f3822ce610c0eeddf2e1bca357b5a0f14540045005300540044004f004d0032004b0038007a0066006100730065006c00570049004e0037005500530045005200310000000000000000000000000000000000000000000000000021d98b012b5ef3c249d2cb2aa82a0207010100000000000092214acb6e5dcd01e122cd5b3aa9fb3f0000000002001400540045005300540044004f004d0032004b00380001001000570049004e0032004b0038004400430004002a00740065007300740064006f006d0032006b0038002e007a0066006100730065006c002e006e006500740003003c00570069006e0032006b003800440043002e00740065007300740064006f006d0032006b0038002e007a0066006100730065006c002e006e006500740005002a00740065007300740064006f006d0032006b0038002e007a0066006100730065006c002e006e00650074000700080092214acb6e5dcd0106000400020000000800300030000000000000000000000000200000a1a4919aacc74f35c033582c72b7db8d73b4011bb3aa6df24aaf104199adc4280a0010000000000000000000000000000000000009001e0063006900660073002f00310030002e0031002e00310030002e0031003100000000000000000000000000ffb017067c1881f645406df717bcbb6e'
#z = test2.scan(/../).map { | s| s.to_i(16) }
#q = z.pack("C*")
#test = ZFNtlm::Message.new(q)
#test.parsetype3
#woof = test.buildtype3.unpack("H*")

#if (q[0,8] == "\x4e\x54\x4c\x4d\x53\x53\x50\x00") then puts "ntlmssp!" end
#if (q[8,4] == "\x03\x00\x00\x00") then puts "Type3 Msg" end

#print q[domainnameoffset,domainnamelen]
#print "/"
#puts q[usernameoffset,usernamelen]
#print "NTHash: "
#puts q[ntlmoffset,ntlmlen].unpack("H*")[0]
#TODO : Add ntlmv2 decoding and modifying of data
#flags = q[60,4]
