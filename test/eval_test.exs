defmodule Greenbar.EvalTest do

  use Greenbar.Test.Support.TestCase
  alias Greenbar.Engine

  setup_all do
    {:ok, engine} = Engine.new
    {:ok, engine} = Engine.add_tag(engine, Greenbar.Test.Support.PrefixTag)
    [engine: engine]
  end

  defp eval_template(engine, name, template, args) do
    engine = Engine.compile!(engine, name, template)
    Engine.eval!(engine, name, args)
  end

  test "list variables render correctly", context do
    result = eval_template(context.engine, "solo_variable", Templates.solo_variable, %{"item" => ["a","b","c"]})
    Assertions.directive_structure(result, [:text, :newline, :text])
    assert Enum.at(result, 2) == %{name: :text, text: "[\"a\",\"b\",\"c\"]."}
  end

  test "map variables render correctly", context do
    result = eval_template(context.engine, "solo_variable", Templates.solo_variable, %{"item" => %{"name" => "baz"}})
    Assertions.directive_structure(result, [:text, :newline, :text])
  end

  test "parent/child scopes work", context do
    data = %{"items" => ["a","b","c"]}
    result = eval_template(context.engine, "parent_child_scopes", Templates.parent_child_scopes, data)
    Assertions.directive_structure(result, [:text, :newline, # Header
                                            :text, :fixed_width, :newline, # a
                                            :text, :fixed_width, :newline, # b
                                            :text, :fixed_width, :newline, # c
                                            :text]) # Footer
  end

  test "indexed variables work", context do
    data = %{"results" => [%{"documentation" => "These are my docs"}]}
    result = eval_template(context.engine, "documentation", Templates.documentation, data)
    assert [%{name: :text, text: "These are my docs"}] == result
  end

  test "real world template works", context do
    data = %{"results" => [%{"id" => "bundle_123", "name" => "First Bundle", "enabled_version" => %{"version" => "1.1"}},
                           %{"id" => "bundle_124", "name" => "Second Bundle", "enabled_version" => %{"version" => "1.2"}},
                           %{"id" => "bundle_125", "name" => "Third Bundle", "enabled_version" => %{"version" => "1.3"}}]}
    result = eval_template(context.engine, "bundles", Templates.bundles, data)
    Assertions.directive_structure(result, [:text, :newline, :newline, #header
                                            :text, :newline, # Bundle ID
                                            :text, :newline, # Bundle Name
                                            :text, :newline, # Enabled Version
                                            :text, :newline, # Bundle ID
                                            :text, :newline, # Bundle Name
                                            :text, :newline, # Enabled Version
                                            :text, :newline, # Bundle ID
                                            :text, :newline, # Bundle Name
                                            :text]) # Enabled Version

  end

  test "if tag", context do
    # Bound? fails
    result = eval_template(context.engine, "if_tag", Templates.if_tag, %{})
    Assertions.directive_structure(result, [:text])

    # Bound? succeeds
    result = eval_template(context.engine, "if_tag", Templates.if_tag, %{"item" => "`Kilroy was here`"})
    Assertions.directive_structure(result, [:text, :newline, :fixed_width])
  end

  test "not_empty? check works", context do
    result = eval_template(context.engine, "not_empty_check", Templates.not_empty_check, %{"user_creators" => ["bob", "sue", "frank"]})
    Assertions.directive_structure(result, [:newline, :text, :newline, :newline, #header
                                            :text, :newline, # bob
                                            :text, :newline, # sue
                                            :text]) #frank
    result = eval_template(context.engine, "not_empty_check", Templates.not_empty_check, %{})
    assert length(result) == 0
  end

  test "!= check works", context do
    result = eval_template(context.engine, "not_equal_check", Templates.not_equal_check, %{"results" =>
                                                                                            [%{"name" => "foo", "state" => "running",
                                                                                               "id" => "123"},
                                                                                             %{"name" => "bar", "state" => "terminated",
                                                                                               "id" => "456"}]})
    assert result === [%{children: [
                            %{name: :text, text: "ID: 123"},
                            %{name: :newline},
                            %{name: :text, text: "Name: foo"},
                            %{name: :newline},
                            %{name: :text, text: "State: running"}],
                         color: "green", fields: [], name: :attachment},
                       %{children: [
                            %{name: :text, text: "ID: 456"},
                            %{name: :newline},
                            %{name: :text, text: "Name: bar"},
                            %{name: :newline},
                            %{name: :text, text: "State: terminated"}],
                         color: "red", fields: [], name: :attachment}]
  end

  test "building ordered lists works", context do
    result = eval_template(context.engine, "generated_ordered_list", Templates.generated_ordered_list, %{"users" => [%{"name" => "Susan"},
                                                                                                                     %{"name" => "Oscar"}]})
    assert result === [%{children: [%{children: [%{name: :text, text: "Susan"}, %{name: :newline}],
                                      name: :list_item},
                                    %{children: [%{name: :text, text: "Oscar"}, %{name: :newline}],
                                      name: :list_item}], name: :ordered_list}]
  end

  test "building unordered lists works", context do
    result = eval_template(context.engine, "generated_unordered_list", Templates.generated_unordered_list, %{"users" => [%{"name" => "Mr. Hooper"},
                                                                                                                         %{"name" => "Grover"}]})
    assert result === [%{children: [%{children: [%{name: :text, text: "Mr. Hooper"}, %{name: :newline}],
                                      name: :list_item},
                                    %{children: [%{name: :text, text: "Grover"}, %{name: :newline}],
                                      name: :list_item}], name: :unordered_list}]
  end

  test "building dynamic lists works", context do
    [result] = eval_template(context.engine, "dynamic_list", Templates.dynamic_list, %{"users" => [%{"name" => "Mr. Hooper"},
                                                                                                   %{"name" => "Grover"}],
                                                                                       "li" => "*"})
    assert result.name == :unordered_list
    [result] = eval_template(context.engine, "dynamic_list", Templates.dynamic_list, %{"users" => [%{"name" => "Mr. Hooper"},
                                                                                                   %{"name" => "Grover"}],
                                                                                       "li" => "1."})
    assert result.name == :ordered_list
  end

  test "nested lists work", context do
    result = eval_template(context.engine, "nested_lists", Templates.nested_lists, %{"groups" => [%{"name" => "admins",
                                                                                                    "users" => [%{"name" => "Big Bird"}]},
                                                                                                  %{"name" => "accounting",
                                                                                                    "users" => [%{"name" => "The Count"}]}]})
    assert result === [%{children: [%{children: [%{name: :text, text: "admins"}, %{name: :newline}],
                                      name: :list_item}], name: :unordered_list},
                       %{children: [%{children: [%{name: :text, text: "Big Bird"}, %{name: :newline}],
                                      name: :list_item}], name: :ordered_list},
                       %{children: [%{children: [%{name: :text, text: "accounting"},
                                                 %{name: :newline}], name: :list_item}], name: :unordered_list},
                       %{children: [%{children: [%{name: :text, text: "The Count"},
                                                 %{name: :newline}], name: :list_item}], name: :ordered_list}]
  end

  test "multiple same-scope each loops work", context do
    result = eval_template(context.engine, "bundle_details", Templates.bundle_details, %{"results" => [
                                                                                         %{"id" => "aaaa-bbbb-cccc-dddd-eeee-ffff",
                                                                                           "name" => "my_bundle",
                                                                                           "versions" => [%{"version" => "0.0.1"},
                                                                                                          %{"version" => "0.0.2"},
                                                                                                          %{"version" => "0.0.3"}],
                                                                                           "enabled_version" => %{"version" => "0.0.3"},
                                                                                           "relay_groups" => [%{"name" => "preprod"},
                                                                                                              %{"name" => "prod"}]}]})
    assert result === [%{name: :text, text: "ID: aaaa-bbbb-cccc-dddd-eeee-ffff"}, %{name: :newline},
                       %{name: :text, text: "Name: my_bundle"}, %{name: :newline},
                       %{name: :text, text: "Versions: 0.0.1"}, %{name: :newline},
                       %{name: :text, text: "0.0.2"}, %{name: :newline},
                       %{name: :text, text: "0.0.3"}, %{name: :newline},
                       %{name: :text, text: "Enabled Version: 0.0.3"}, %{name: :newline},
                       %{name: :text, text: "Relay Groups: preprod"}, %{name: :newline},
                       %{name: :text, text: "prod"}]
  end

  test "length check works", context do
    result = eval_template(context.engine, "length_test", Templates.length_test, %{"pets" => %{"cats" => [1,2]}})
    assert result === [%{name: :text, text: "No puppies :("}]
    result = eval_template(context.engine, "length_test", Templates.length_test, %{"pets" => %{"cats" => [1,2],
                                                                                               "puppies" => []}})
    assert result === [%{name: :text, text: "No puppies :("}]
    result = eval_template(context.engine, "length_test", Templates.length_test, %{"pets" => %{"cats" => [1,2],
                                                                                               "puppies" => [1]}})
    assert result === [%{name: :text, text: "One puppy"}]
    result = eval_template(context.engine, "length_test", Templates.length_test, %{"pets" => %{"cats" => [1,2],
                                                                                               "puppies" => [1,2,3]}})
    assert result === [%{name: :text, text: "Lots of puppies!"}]
  end

  test "bound check works", context do
    result = eval_template(context.engine, "bound_check", Templates.bound_check, %{})
    assert result === [%{name: :text, text: "No user creators available."}]
    result = eval_template(context.engine, "bound_check", Templates.bound_check, %{"user_creators" => [1,2]})
    assert result == [%{name: :text, text: "2 user creator(s) available."}]
  end

  test "building tables with each tag", context do
    result = eval_template(context.engine, "each_table", Templates.table_with_each, %{"users" => [%{"first_name" => "Darth",
                                                                                                    "last_name" => "Vader"},
                                                                                                  %{"first_name" => "C3P0",
                                                                                                    "last_name" => "Botston"},
                                                                                                  %{"first_name" => "Jabba",
                                                                                                    "last_name" => "Huttman"}]})
    assert result === [%{children: [%{children: [%{children: [%{name: :text, text: "First Name"}],
                                                   name: :table_cell},
                                                 %{children: [%{name: :text, text: "Last Name"}], name: :table_cell},
                                                 %{children: [%{name: :text, text: "Foo"}], name: :table_cell}],
                                      name: :table_header},
                                    %{children: [%{children: [%{name: :text, text: "Darth"}],
                                                   name: :table_cell},
                                                 %{children: [%{name: :text, text: "Vader"}], name: :table_cell},
                                                 %{children: [%{name: :text, text: "Bar"}], name: :table_cell}],
                                      name: :table_row},
                                    %{children: [%{children: [%{name: :text, text: "C3P0"}], name: :table_cell},
                                                 %{children: [%{name: :text, text: "Botston"}], name: :table_cell},
                                                 %{children: [%{name: :text, text: "Bar"}], name: :table_cell}],
                                      name: :table_row},
                                    %{children: [%{children: [%{name: :text, text: "Jabba"}],
                                                   name: :table_cell},
                                                 %{children: [%{name: :text, text: "Huttman"}], name: :table_cell},
                                                 %{children: [%{name: :text, text: "Bar"}], name: :table_cell}],
                                      name: :table_row}], name: :table}]
  end

  test "wrapping body with attachment tag works", context do
    result = eval_template(context.engine, "attachment_tag", Templates.attachment_tag, %{"bundles" => [%{"name" => "foo",
                                                                                                         "status" => "enabled"},
                                                                                                       %{"name" => "bar",
                                                                                                         "status" => "enabled"},
                                                                                                       %{"name" => "baz",
                                                                                                         "status" => "disabled"}],
                                                                                         "color" => "blue",
                                                                                         "woot" => 123})
    assert result === [%{children: [%{children: [%{children: [%{children: [%{name: :text,
                                                                             text: "Bundle"}], name: :table_cell},
                                                              %{children: [%{name: :text, text: "Status"}], name: :table_cell}],
                                                   name: :table_header},
                                                 %{children: [%{children: [%{name: :text, text: "foo"}],
                                                                name: :table_cell},
                                                              %{children: [%{name: :text, text: "enabled"}], name: :table_cell}],
                                                   name: :table_row},
                                                 %{children: [%{children: [%{name: :text, text: "bar"}],
                                                                name: :table_cell},
                                                              %{children: [%{name: :text, text: "enabled"}], name: :table_cell}],
                                                   name: :table_row},
                                                 %{children: [%{children: [%{name: :text, text: "baz"}],
                                                                name: :table_cell},
                                                              %{children: [%{name: :text, text: "disabled"}], name: :table_cell}],
                                                   name: :table_row}], name: :table}],
                         name: :attachment,
                         color: "blue",
                         fields: [%{short: false, title: "custom_field", value: 123}]}]
  end

  test "wrapping body works", context do
    result = eval_template(context.engine, "foo1", "~prefix~\nThis is a test\nThis is another test\n~end~", %{})
    assert result === [%{name: :text, text: "This is the prefix tag."},
                       %{name: :newline}, %{name: :text, text: "This is a test"},
                       %{name: :newline}, %{name: :text, text: "This is another test"}]
  end

  test "attachment tag's body is in the correct order", context do
    result = eval_template(context.engine, "foo2", "~attachment color=\"red\"~\nThis is a test\n```\nThis is another test\n```\n~end~", %{})
    assert result === [%{children: [%{name: :text, text: "This is a test"}, %{name: :newline},
                                    %{name: :fixed_width, text: "\nThis is another test\n"}],
                         color: "red", fields: [], name: :attachment}]
  end

  test "bold and bullets are parsed correctly", context do
    result = eval_template(context.engine, "bold_and_bullets", Templates.bold_and_bullets, %{})
    assert result === [%{name: :bold, text: "test"}, %{name: :newline},
                       %{children: [%{children: [%{name: :text, text: "one"}, %{name: :newline}],
                                      name: :list_item},
                                    %{children: [%{name: :text, text: "two"}, %{name: :newline}],
                                      name: :list_item},
                                    %{children: [%{name: :text, text: "three"}, %{name: :newline}],
                                      name: :list_item}],
                         name: :unordered_list}]
  end
end
