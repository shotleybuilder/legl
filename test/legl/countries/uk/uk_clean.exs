defmodule Test.Legl.Countries.Uk.UkClean do
  describe "join_empty_numbered/1" do
    test "removes \n" do
      binary = ~s/(a)\nFoo\n(b)\nBar\n(i)\nFoo\n(ii)\nBar/

      s = UK.Parser.join_empty_numbered(binary)
      assert s == "(a) Foo\n(b) Bar\n(i) Foo\n(ii) Bar"
    end

    test "removes \n in text" do
      binary = ~s/(a)\nthe Secretary of State;\n(b)\nthe Agency;\n(c)\nSEPA; or/
      s = UK.Parser.join_empty_numbered(binary)
      assert s == ~s/(a) the Secretary of State;\n(b) the Agency;\n(c) SEPA; or/
    end
  end
end
