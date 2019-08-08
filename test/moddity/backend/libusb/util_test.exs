defmodule Moddity.Backend.Libusb.UtilTest do
  use ExUnit.Case, async: true

  alias Moddity.Backend.Libusb.Util

  doctest Util

  describe "build_command_request_bytes/1" do
    test "It adds the $ prefix, ; postfix, and length checksum bytes" do
      command = ~s({"transport":{"attrs":["request","twoway"],"id":5},"data":{"command":{"idx":22,"name":"wifi_client_get_status","args":{"interface_t":0}}}})
      actual = Util.build_command_request_bytes(command)
      expected = "$" <> Base.decode16!("8B0074FF") <> command <> ";"
      assert actual == expected
    end
  end
end
