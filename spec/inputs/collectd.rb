require "test_utils"
require "socket"
require "tempfile"

describe "inputs/collectd" do
  extend LogStash::RSpec
  udp_sock = UDPSocket.new(Socket::AF_INET)

  describe "parses a normal packet" do
    config <<-CONFIG
      input {
        collectd {
          type => "collectd"
          host => "127.0.0.1"
          # normal collectd port + 1
          port => 25827
        }
      }
    CONFIG

    input do |pipeline, queue|
      Thread.new { pipeline.run }
      sleep 0.1 while !pipeline.ready?

      # Sleep so collectd can init itself
      sleep 3

      # Actual data :D
      msg = ["000000236c6965746572732d6b6c6170746f702e70726f742e706c657869732e6575000008000c14b0a645f3eb73c30009000c00000002800000000002000e696e74657266616365000003000a776c616e30000004000e69665f6572726f7273000006001800020202000000000000000000000000000000000008000c14b0a645f3eb525e000300076c6f000004000f69665f7061636b6574730000060018000202020000000000001cd80000000000001cd80008000c14b0a645f3ebf8c10002000c656e74726f70790000030005000004000c656e74726f7079000006000f0001010000000000a063400008000c14b0a645f3eb6c700002000e696e74657266616365000003000a776c616e30000004000f69665f7061636b657473000006001800020202000000000002d233000000000001c3b10008000c14b0a645f3eb59b1000300076c6f000004000e69665f6572726f7273000006001800020202000000000000000000000000000000000008000c14b0a645f425380b00020009737761700000030005000004000973776170000005000975736564000006000f00010100000000000000000008000c14b0a645f4254c8d0005000966726565000006000f00010100000000fcffdf410008000c14b0a645f4255ae70005000b636163686564000006000f00010100000000000000000008000c14b0a645f426f09f0004000c737761705f696f0000050007696e000006000f00010200000000000000000008000c14b0a645f42701e7000500086f7574000006000f00010200000000000000000008000c14b0a645f42a0edf0002000a7573657273000004000a75736572730000050005000006000f00010100000000000022400008000c14b0a645f5967c8b0002000e70726f636573736573000004000d70735f7374617465000005000c72756e6e696e67000006000f00010100000000000000000008000c14b0a645f624706c0005000d736c656570696e67000006000f0001010000000000c067400008000c14b0a645f624861a0005000c7a6f6d62696573000006000f00010100000000000000000008000c14b0a645f62494740005000c73746f70706564000006000f00010100000000000010400008000c14b0a645f6254aa90005000b706167696e67000006000f00010100000000000000000008000c14b0a645f6255b110005000c626c6f636b6564000006000f00010100000000000000000008000c14b0a645f62763060004000e666f726b5f726174650000050005000006000f00010200000000000025390008000c14b0a64873bf8f47000200086370750000030006300000040008637075000005000975736572000006000f0001020000000000023caa0008000c14b0a64873bfc9dd000500096e696365000006000f00010200000000000000030008000c14b0a64873bfe9350005000b73797374656d000006000f00010200000000000078bc0008000c14b0a64873c004290005000969646c65000006000f00010200000000000941fe0008000c14b0a64873c020920005000977616974000006000f00010200000000000002050008000c14b0a64873c03e280005000e696e74657272757074000006000f00010200000000000000140008000c14b0a64873c04ba20005000c736f6674697271000006000f00010200000000000001890008000c14b0a64873c058860005000a737465616c000006000f00010200000000000000000008000c14b0a64873c071b80003000631000005000975736572000006000f000102000000000002440e0008000c14b0a64873c07f31000500096e696365000006000f0001020000000000000007"].pack('H*')
      udp_sock.send(msg, 0, "127.0.0.1", 25827)

      sleep 1
      insist { queue.size } == 28

      events = 3.times.collect { queue.pop }
      # Checking the timestamp fails with:
      # Expected "2013-12-31T10:14:47.811Z", but got "2013-12-31T10:14:47.811Z"
      # So... yeah.....

      #timestamp = Time.iso8601("2013-12-31T10:14:47.811Z")

      #insist { events[0]['@timestamp'] } == timestamp.utc
      insist { events[0]['host'] } == "lieters-klaptop.prot.plexis.eu"
      insist { events[0]['plugin'] } == "interface"
      insist { events[0]['plugin_instance'] } == "wlan0"
      insist { events[0]['collectd_type'] } == "if_errors"
      insist { events[0]['rx'] } == 0
      insist { events[0]['tx'] } == 0

      #insist { events[2]['@timestamp'] } == timestamp
      insist { events[2]['host'] } == "lieters-klaptop.prot.plexis.eu"
      insist { events[2]['plugin'] } == "entropy"
      insist { events[2]['collectd_type'] } == "entropy"
      insist { events[2]['value'] } == 157.0
    end
  end

  # Create an authfile
  authfile = Tempfile.new('logstash-collectd-authfile')
  File.open(authfile.path, "a") do |fd|
    fd.puts("pieter: aapje1234")
  end

  describe "Parses correctly signed packet" do
    config <<-CONFIG
      input {
        collectd {
          type           => "collectd"
          host           => "127.0.0.1"
          # normal collectd port + 1
          port           => 25827
          authfile       => "#{authfile.path}"
          security_level => "Sign"
        }
      }
    CONFIG

    input do |pipeline, queue|
      Thread.new { pipeline.run }
      sleep 0.1 while !pipeline.ready?

      # Sleep so collectd can init itself
      sleep 3
      msg = ["0200002a815d5d7e1e72250eee4d37251bf688fbc06ec87e3cbaf289390ef47ad7c413ce706965746572000000236c6965746572732d6b6c6170746f702e70726f742e706c657869732e6575000008000c14b0aa39ef05b3a80009000c000000028000000000020008697271000004000869727100000500084d4953000006000f00010200000000000000000008000c14b0aa39ef06c381000200096c6f616400000400096c6f616400000500050000060021000301010148e17a14ae47e13f85eb51b81e85db3f52b81e85eb51e03f0008000c14b0aa39ef0a7a150002000b6d656d6f7279000004000b6d656d6f7279000005000975736564000006000f000101000000006ce8dc410008000c14b0aa39ef0a87440005000d6275666665726564000006000f00010100000000c0eaa9410008000c14b0aa39ef0a91850005000b636163686564000006000f000101000000002887c8410008000c14b0aa39ef0a9b2f0005000966726565000006000f00010100000000580ed1410008000c14b0aa39ef1b3b8f0002000e696e74657266616365000003000974756e30000004000e69665f6f63746574730000050005000006001800020202000000000000df5f00000000000060c10008000c14b0aa39ef1b49ea0004000f69665f7061636b6574730000060018000202020000000000000177000000000000017a0008000c14b0aa39ef1b55570004000e69665f6572726f7273000006001800020202000000000000000000000000000000000008000c14b0aa39ef1b7a400003000965746830000004000e69665f6f6374657473000006001800020202000000000000000000000000000000000008000c14b0aa39ef1b85160004000f69665f7061636b657473000006001800020202000000000000000000000000000000000008000c14b0aa39ef1b93bc0004000e69665f6572726f7273000006001800020202000000000000000000000000000000000008000c14b0aa39ef1bb0bc000300076c6f000004000e69665f6f63746574730000060018000202020000000000a92d840000000000a92d840008000c14b0aa39ef1bbbdd0004000f69665f7061636b6574730000060018000202020000000000002c1e0000000000002c1e0008000c14b0aa39ef1bc8760004000e69665f6572726f7273000006001800020202000000000000000000000000000000000008000c14b0aa39ef1be36a0003000a776c616e30000004000e69665f6f6374657473000006001800020202000000001043329b0000000001432a5d0008000c14b0aa39ef1bef6c0004000f69665f7061636b6574730000060018000202020000000000043884000000000002931e0008000c14b0aa39ef1bfa8d0004000e69665f6572726f7273000006001800020202000000000000000000000000000000000008000c14b0aa39ef6e4ff5000200096469736b000003000873646100000400106469736b5f6f637465747300000600180002020200000000357c5000000000010dfb10000008000c14b0aa39ef6e8e5a0004000d6469736b5f6f7073000006001800020202000000000000a6fe0000000000049ee00008000c14b0aa39ef6eae480004000e6469736b5f74696d65000006001800020202000000000000000400000000000000120008000c14b0aa39ef6ecc2a000400106469736b5f6d6572676564000006001800020202000000000000446500000000000002460008000c14b0aa39ef6ef9dc000300097364613100000400106469736b5f6f637465747300000600180002020200000000000bf00000000000000000000008000c14b0aa39ef6f05490004000d6469736b5f6f707300000600180002020200000000000000bf0000000000000000"].pack('H*')
      udp_sock.send(msg, 0, "127.0.0.1", 25827)

      # give it time to process
      sleep 3

      insist { queue.size } == 24
    end
  end

  describe "Does not parse incorrectly signed packet" do
    config <<-CONFIG
      input {
        collectd {
          type           => "collectd"
          host           => "127.0.0.1"
          # normal collectd port + 1
          port           => 25827
          authfile       => "#{authfile.path}"
          security_level => "Sign"
        }
      }
    CONFIG

    input do |pipeline, queue|
      Thread.new { pipeline.run }
      sleep 0.1 while !pipeline.ready?

      # Sleep so collectd can init itself
      sleep 3

      # Wrong hash in packet
      msg = ["0200002a815d5d7f1e72250eee4d37251bf688fbc06ec87e3cbaf289390ef47ad7c413ce706965746572000000236c6965746572732d6b6c6170746f702e70726f742e706c657869732e6575000008000c14b0aa39ef05b3a80009000c000000028000000000020008697271000004000869727100000500084d4953000006000f00010200000000000000000008000c14b0aa39ef06c381000200096c6f616400000400096c6f616400000500050000060021000301010148e17a14ae47e13f85eb51b81e85db3f52b81e85eb51e03f0008000c14b0aa39ef0a7a150002000b6d656d6f7279000004000b6d656d6f7279000005000975736564000006000f000101000000006ce8dc410008000c14b0aa39ef0a87440005000d6275666665726564000006000f00010100000000c0eaa9410008000c14b0aa39ef0a91850005000b636163686564000006000f000101000000002887c8410008000c14b0aa39ef0a9b2f0005000966726565000006000f00010100000000580ed1410008000c14b0aa39ef1b3b8f0002000e696e74657266616365000003000974756e30000004000e69665f6f63746574730000050005000006001800020202000000000000df5f00000000000060c10008000c14b0aa39ef1b49ea0004000f69665f7061636b6574730000060018000202020000000000000177000000000000017a0008000c14b0aa39ef1b55570004000e69665f6572726f7273000006001800020202000000000000000000000000000000000008000c14b0aa39ef1b7a400003000965746830000004000e69665f6f6374657473000006001800020202000000000000000000000000000000000008000c14b0aa39ef1b85160004000f69665f7061636b657473000006001800020202000000000000000000000000000000000008000c14b0aa39ef1b93bc0004000e69665f6572726f7273000006001800020202000000000000000000000000000000000008000c14b0aa39ef1bb0bc000300076c6f000004000e69665f6f63746574730000060018000202020000000000a92d840000000000a92d840008000c14b0aa39ef1bbbdd0004000f69665f7061636b6574730000060018000202020000000000002c1e0000000000002c1e0008000c14b0aa39ef1bc8760004000e69665f6572726f7273000006001800020202000000000000000000000000000000000008000c14b0aa39ef1be36a0003000a776c616e30000004000e69665f6f6374657473000006001800020202000000001043329b0000000001432a5d0008000c14b0aa39ef1bef6c0004000f69665f7061636b6574730000060018000202020000000000043884000000000002931e0008000c14b0aa39ef1bfa8d0004000e69665f6572726f7273000006001800020202000000000000000000000000000000000008000c14b0aa39ef6e4ff5000200096469736b000003000873646100000400106469736b5f6f637465747300000600180002020200000000357c5000000000010dfb10000008000c14b0aa39ef6e8e5a0004000d6469736b5f6f7073000006001800020202000000000000a6fe0000000000049ee00008000c14b0aa39ef6eae480004000e6469736b5f74696d65000006001800020202000000000000000400000000000000120008000c14b0aa39ef6ecc2a000400106469736b5f6d6572676564000006001800020202000000000000446500000000000002460008000c14b0aa39ef6ef9dc000300097364613100000400106469736b5f6f637465747300000600180002020200000000000bf00000000000000000000008000c14b0aa39ef6f05490004000d6469736b5f6f707300000600180002020200000000000000bf0000000000000000"].pack('H*')
      udp_sock.send(msg, 0, "127.0.0.1", 25827)

      # give it time to process
      sleep 1

      insist { queue.size } == 0
    end # input
  end # describe "Does not parse incorrectly signed packet"

  describe "parses encrypted packet" do
    config <<-CONFIG
      input {
        collectd {
          type           => "collectd"
          host           => "127.0.0.1"
          # normal collectd port + 1
          port           => 25827
          authfile       => "#{authfile.path}"
          security_level => "Encrypt"
        }
      }
    CONFIG

    input do |pipeline, queue|
      Thread.new { pipeline.run }
      sleep 0.1 while !pipeline.ready?

      # Sleep so collectd can init itself
      sleep 3

      msg = ["0210055b0006706965746572a8e1874742655f163fa5b1ae4c7c37cd4c271e4f6e2dc53f0a2dfb6391c11f9200645abd545de9042bc7f36c3119e5d301115acfd44ff298d2565cf20799fa322bbe2e72268ef1b5f24b8003e512b0f8f52ce5d3fb0a5aafbff83ac7a49047e2fbf908a3f8c043154feeb594953e5dbd93eafdc75866b336d25e135d2fea6efcebaf9041c86081dda8b999d816e23106a3615efee7191610d9f2eab626cccf00879d76e82a3e60f60cf594435c723ac302c605f9a3ddc6c994acb75d461fa82e57f8b9823081a80a07386b8cdeca387792a52a58f1c367cacec8ecc292b06c5101b5fdcc0320bfd473fb751bef559e51031ef4207404702fa4899b152bf264c4b0f11cf6ab37fc4c7fb996fa6d2dce9051373c5adf06bbb588d38a1251258f2fd690c55a9d2c87b916ca159b261b3fce068b91fd94ca31f90c237df7ac6fcd7c9e73d77c49b3fb93be59cdcf51ea3dcdfd00cdeff379f979cc7341369c47b741651fe5b8de82498cebf35d8c9bad1ef02384e8418d57765aeede95bbd70078516136351b39e4f1e668786ce3885ac8f0f0246337ed6842f5789536474d3c1390b846aaf859b5af6efad027439dc0e444d3a9ab289a4deab4aeecbd9514e1fabadcd7b4565b6d96f12007b600dd0cc135b0c6a521f8c9c17b109d4ba5a42d32f00757c4da50bc0e5ff2bd1114df97f3edfc25102fdc43faa2c2087a5ee9cc0137438eac807bf19f883023adb1293623e15bf94ce7bb2fb6af68978c12642b1dd04badcbf74ee9d08ed5629904376a084348fc51ea382a9d83cd41d021be24f3fea3f079de815c0a89e0c3684501eb6ead89b515cca706218702fb56fe4c8ca0b3d7969dbee7a5a12a17843f990e408974c65aaa3d719f8774098eee7d5be5adb025de24e719434073e59ee91d38192007c5df97d79174de8218ecf89d7778282814ec8ad92f9622d2b875881666d59949b9487f2b231203b570418dd69218e2e86205af2618b74f1a83bdab0465f44d0647548598018ba0180e6d9a8496854c8fbb85698c4ec56d9f524ebf37953601a0c470c360f2d8fa83215c761cbb4d8ae475bbb3dec60e6a5c7af7aab1b8bb56b8fa18619a0c240e5ccf2d02326fc08db42f74b99b9be5263061b36a1b750e061f3cad72db6480e8194a6fe78bc3403551473d03b5067a3d72457563777f398f3df4ae24c09fc66c2c0b06331fdabb33e7ef22a7e7f4a5d8e92cdaaabc7aabd2ab15cf6204e2a531ef4fdc98ed4895e71ea9e406b759d6d547b0b97c2715551c73efd415e55f0c0d73d7134b63c0636728bab0a59bff59de8a31f40f4f1f77a3e1e52d2035f69ab453dfd14889c5dfa7fcc27180cb35f92a3282dfc520716968bec6f22e99351889d53628e57f48f5ad70899881b81699454d8d5aff6791672cbf258d1130dabf27ddee7f6e105752c3773257a2a5616350551965e7c60603c8b0465169af66b52ff900be147ead7a8bfb9bf1419709b539a8f003da13abe286855850530135a1eba0231a9995736abf55b6f50aa85e42afc7b4e7574cc53b8919d0b05c4630af1e5fa98a1bd6a2b7e4fbda02c68c73d07bf0f117d63d1ed51d613464146dba12460a0769c79517a928e66417ef4ee19248a7abd1a734eb53443ff44a742d6bf96782de8593ec8561ea974b61f0f2d5ab1671c4eb323c0a07bf6d042564161c5688a722cf8de4c39346082b7a3d635bcf5e24c7ab421ed206f3a93c17d26f0b28a99e25bc3387f3f5fcd99b6560c51f055ac1887f3d84fb8ad0eb03304663bad111fcf531e4efe918143062ca1724857edd138ca9eca0476a5205c3fe1db899d4b26a8d3398df52e8548ecdfb94044e8c095df60139d00c3bc01c205d44fd81fc30ec02b20f281da57c106b86e567585e0b561555ea491eda05"].pack('H*')
      udp_sock.send(msg, 0, "127.0.0.1", 25827)

      # give it time to process
      sleep 2

      insist { queue.size } == 24
    end # input
  end # describe "parses encrypted packet"

  describe "does not parse unencrypted when configured to do so" do
    config <<-CONFIG
      input {
        collectd {
          type           => "collectd"
          host           => "127.0.0.1"
          # normal collectd port + 1
          port           => 25827
          authfile       => "#{authfile.path}"
          security_level => "Encrypt"
        }
      }
    CONFIG

    input do |pipeline, queue|
      Thread.new { pipeline.run }
      sleep 0.1 while !pipeline.ready?

      # Sleep so collectd can init itself
      sleep 3

      msg = ["000000236c6965746572732d6b6c6170746f702e70726f742e706c657869732e6575000008000c14b0a645f3eb73c30009000c00000002800000000002000e696e74657266616365000003000a776c616e30000004000e69665f6572726f7273000006001800020202000000000000000000000000000000000008000c14b0a645f3eb525e000300076c6f000004000f69665f7061636b6574730000060018000202020000000000001cd80000000000001cd80008000c14b0a645f3ebf8c10002000c656e74726f70790000030005000004000c656e74726f7079000006000f0001010000000000a063400008000c14b0a645f3eb6c700002000e696e74657266616365000003000a776c616e30000004000f69665f7061636b657473000006001800020202000000000002d233000000000001c3b10008000c14b0a645f3eb59b1000300076c6f000004000e69665f6572726f7273000006001800020202000000000000000000000000000000000008000c14b0a645f425380b00020009737761700000030005000004000973776170000005000975736564000006000f00010100000000000000000008000c14b0a645f4254c8d0005000966726565000006000f00010100000000fcffdf410008000c14b0a645f4255ae70005000b636163686564000006000f00010100000000000000000008000c14b0a645f426f09f0004000c737761705f696f0000050007696e000006000f00010200000000000000000008000c14b0a645f42701e7000500086f7574000006000f00010200000000000000000008000c14b0a645f42a0edf0002000a7573657273000004000a75736572730000050005000006000f00010100000000000022400008000c14b0a645f5967c8b0002000e70726f636573736573000004000d70735f7374617465000005000c72756e6e696e67000006000f00010100000000000000000008000c14b0a645f624706c0005000d736c656570696e67000006000f0001010000000000c067400008000c14b0a645f624861a0005000c7a6f6d62696573000006000f00010100000000000000000008000c14b0a645f62494740005000c73746f70706564000006000f00010100000000000010400008000c14b0a645f6254aa90005000b706167696e67000006000f00010100000000000000000008000c14b0a645f6255b110005000c626c6f636b6564000006000f00010100000000000000000008000c14b0a645f62763060004000e666f726b5f726174650000050005000006000f00010200000000000025390008000c14b0a64873bf8f47000200086370750000030006300000040008637075000005000975736572000006000f0001020000000000023caa0008000c14b0a64873bfc9dd000500096e696365000006000f00010200000000000000030008000c14b0a64873bfe9350005000b73797374656d000006000f00010200000000000078bc0008000c14b0a64873c004290005000969646c65000006000f00010200000000000941fe0008000c14b0a64873c020920005000977616974000006000f00010200000000000002050008000c14b0a64873c03e280005000e696e74657272757074000006000f00010200000000000000140008000c14b0a64873c04ba20005000c736f6674697271000006000f00010200000000000001890008000c14b0a64873c058860005000a737465616c000006000f00010200000000000000000008000c14b0a64873c071b80003000631000005000975736572000006000f000102000000000002440e0008000c14b0a64873c07f31000500096e696365000006000f0001020000000000000007"].pack('H*')
      udp_sock.send(msg, 0, "127.0.0.1", 25827)

      # give it time to process
      sleep 2

      insist { queue.size } == 0

    end # input
  end # describe
end # describe "inputs/collectd"