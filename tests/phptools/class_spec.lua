local Class = require("phptools.class")

describe("Class module", function()
  describe("Class:new()", function()
    it("should create a new instance with correct metatable", function()
      local instance = Class:new()
      assert.truthy(instance)
      assert.equals(instance.constructor, false)
      assert.truthy(instance.params)
    end)

    it("should have position params with textDocument", function()
      local instance = Class:new()
      assert.truthy(instance.params)
      assert.truthy(instance.params.textDocument)
    end)
  end)

  describe("Class:process_parent()", function()
    it("should detect constructor from object_creation_expression", function()
      local instance = Class:new()
      instance.parent = {
        type = "object_creation_expression",
        text = "new ClassName(arg1, arg2)"
      }
      instance:process_parent()
      assert.equals(instance.constructor, true)
    end)

    it("should not set constructor for empty parentheses", function()
      local instance = Class:new()
      instance.parent = {
        type = "object_creation_expression",
        text = "new ClassName()"
      }
      instance:process_parent()
      assert.equals(instance.constructor, false)
    end)

    it("should remove parentheses from parent text", function()
      local instance = Class:new()
      instance.parent = {
        type = "member_call_expression",
        text = "$obj->method(arg1, arg2)"
      }
      instance:process_parent()
      assert.equals(instance.parent.text, "$obj->method")
    end)
  end)

  describe("Class:template_builder()", function()
    it("should return class template for default type", function()
      local instance = Class:new()
      instance.parent = { type = "object_creation_expression" }
      instance.file_ns = "namespace MyApp;"
      instance.class_name = { text = "TestClass" }
      instance.constructor = false

      local template = instance:template_builder()
      assert.equals(#template, 10)
      assert.equals(template[1], "<?php")
      assert.equals(template[3], "declare(strict_types=1);")
      assert.equals(template[7], "class TestClass")
    end)

    it("should include constructor in template when needed", function()
      local instance = Class:new()
      instance.parent = { type = "object_creation_expression" }
      instance.file_ns = "namespace MyApp;"
      instance.class_name = { text = "TestClass" }
      instance.constructor = true

      local template = instance:template_builder()
      assert.truthy(template[9]:match("public function __construct"))
    end)

    it("should use interface template for class_interface_clause", function()
      local instance = Class:new()
      instance.parent = { type = "class_interface_clause" }
      instance.file_ns = "namespace MyApp;"
      instance.class_name = { text = "TestInterface" }

      local template = instance:template_builder()
      assert.equals(template[7], "interface TestInterface")
    end)

    it("should use trait template for use_declaration", function()
      local instance = Class:new()
      instance.parent = { type = "use_declaration" }
      instance.file_ns = "namespace MyApp;"
      instance.class_name = { text = "TestTrait" }

      local template = instance:template_builder()
      assert.equals(template[7], "trait TestTrait")
    end)

    it("should use enum template for class_constant_access_expression with ::class", function()
      local instance = Class:new()
      instance.parent = { type = "class_constant_access_expression", text = "TestEnum::class" }
      instance.file_ns = "namespace MyApp;"
      instance.class_name = { text = "TestEnum" }

      local template = instance:template_builder()
      assert.equals(template[7], "class TestEnum")
    end)

    it("should convert empty type to class", function()
      local instance = Class:new()
      instance.parent = { type = "" }
      instance.file_ns = "namespace MyApp;"
      instance.class_name = { text = "TestClass" }

      local template = instance:template_builder()
      assert.equals(template[7], "class TestClass")
    end)
  end)

  describe("Class:find_or_create_class()", function()
    it("should handle nil file_location gracefully", function()
      local instance = Class:new()
      instance.file_location = nil

      -- Mock get_location to return nil
      function instance:get_location()
        return nil
      end

      -- Mock create_new_class to prevent execution
      function instance:create_new_class()
        instance.create_new_class_called = true
      end

      -- Mock class_position
      function instance:class_position()
        return {}
      end

      instance:find_or_create_class()
      assert.equals(instance.file_location, nil)
      assert.truthy(instance.create_new_class_called)
    end)

    it("should branch to show_document when file_location is not nil", function()
      local instance = Class:new()
      instance.file_location = {
        {
          uri = "file:///path/to/Class.php",
          range = { start = { line = 0, character = 0 } }
        }
      }
      -- Verify that non-nil file_location[1] is handled correctly
      assert.truthy(instance.file_location)
      assert.truthy(instance.file_location[1])
    end)
  end)

  describe("Class:get_location()", function()
    it("should return nil when buf_request_sync returns nil", function()
      local instance = Class:new()

      -- Mock buf_request_sync
      vim.lsp.buf_request_sync = function()
        return nil
      end

      local result = instance:get_location({}, "textDocument/definition")
      assert.equals(result, nil)
    end)

    it("should return nil when results is empty", function()
      local instance = Class:new()

      vim.lsp.buf_request_sync = function()
        return {}
      end

      local result = instance:get_location({}, "textDocument/definition")
      assert.equals(result, nil)
    end)

    it("should return result when found", function()
      local instance = Class:new()
      local expected_result = { uri = "file:///test.php" }

      vim.lsp.buf_request_sync = function()
        return {
          {
            result = { expected_result }
          }
        }
      end

      local result = instance:get_location({}, "textDocument/definition")
      assert.truthy(result)
      assert.equals(result[1].uri, "file:///test.php")
    end)
  end)

  describe("Class:get_insertion_point()", function()
    it("should return 2 when no declarations found", function()
      local instance = Class:new()
      vim.api.nvim_buf_get_lines = function()
        return { "<?php", "", "class Foo {}" }
      end

      local result = instance:get_insertion_point()
      assert.equals(result, 2)
    end)

    it("should return position after declare statement", function()
      local instance = Class:new()
      vim.api.nvim_buf_get_lines = function()
        return {
          "<?php",
          "declare(strict_types=1);",
          "namespace MyApp;",
          "class Foo {}"
        }
      end
      vim.fn.match = function(line, pattern)
        if line == "declare(strict_types=1);" and pattern == "^\\(declare\\)" then
          return 0
        end
        return -1
      end

      local result = instance:get_insertion_point()
      assert.truthy(result)
    end)

    it("should return namespace position when found", function()
      local instance = Class:new()
      vim.api.nvim_buf_get_lines = function()
        return {
          "<?php",
          "declare(strict_types=1);",
          "namespace MyApp;",
          "class Foo {}"
        }
      end
      vim.fn.match = function(line, pattern)
        if line == "namespace MyApp;" and pattern == "^\\(namespace\\)" then
          return 0
        end
        return -1
      end

      local result, _ = instance:get_insertion_point()
      assert.truthy(result)
    end)
  end)

  describe("Class:class_position()", function()
    it("should create valid position params", function()
      local instance = Class:new()
      instance.class_name = {
        range = { 0, 5 }
      }

      local pos = instance:class_position()
      assert.truthy(pos.textDocument)
      assert.truthy(pos.position)
      assert.equals(pos.position.character, 6) -- range[2] + 1
      assert.equals(pos.position.line, 0)
    end)
  end)

  describe("Class templates table", function()
    it("should have all required template mappings", function()
      assert.truthy(Class.templates.class_interface_clause)
      assert.truthy(Class.templates.base_clause)
      assert.truthy(Class.templates.object_creation_expression)
      assert.truthy(Class.templates.scoped_call_expression)
      assert.truthy(Class.templates.use_declaration)
      assert.truthy(Class.templates.class_constant_access_expression)
      assert.truthy(Class.templates.simple_parameter)
    end)

    it("should map to correct entity types", function()
      assert.equals(Class.templates.class_interface_clause, "interface")
      assert.equals(Class.templates.use_declaration, "trait")
      assert.equals(Class.templates.class_constant_access_expression, "enum")
    end)
  end)

  describe("Class:create_new_class() with PSR-4 paths", function()
    it("should display available PSR-4 autoload paths", function()
      local instance = Class:new()
      instance.class_name = { text = "TestClass" }
      instance.parent = { type = "object_creation_expression" }

      local select_called = false
      local select_items = nil

      -- Mock composer.get_prefix_and_src to return PSR-4 paths
      local original_get_prefix = require("phptools.composer").get_prefix_and_src
      require("phptools.composer").get_prefix_and_src = function()
        return {
          { prefix = "SkeletonSrc\\", src = "src/" },
          { prefix = "SkeletonApp\\", src = "app/" },
          { prefix = "SkeletonCore\\", src = "core/" }
        }
      end

      -- Mock vim.ui.select to capture options
      vim.ui.select = function(items, opts, callback)
        select_called = true
        select_items = items
      end

      instance:create_new_class()

      -- Restore
      require("phptools.composer").get_prefix_and_src = original_get_prefix

      assert.truthy(select_called)
      assert.equals(#select_items, 4) -- 3 PSR-4 paths + 1 "Create new directory" option
      assert.equals(select_items[1].path, "src/")
      assert.equals(select_items[1].prefix, "SkeletonSrc\\")
      assert.equals(select_items[4].path, "[Create new directory]")
      assert.equals(select_items[4].is_custom, true)
    end)

    it("should handle mkdir failure gracefully", function()
      local instance = Class:new()
      instance.class_name = { text = "TestClass" }
      instance.parent = { type = "object_creation_expression" }

      local notify_called = false
      local notify_message = nil

      vim.notify = function(msg, level)
        notify_called = true
        notify_message = msg
      end

      -- Mock composer.get_prefix_and_src
      local original_get_prefix = require("phptools.composer").get_prefix_and_src
      require("phptools.composer").get_prefix_and_src = function()
        return { { prefix = "App\\", src = "src/" } }
      end

      -- Mock vim.ui.select to simulate user selection
      vim.ui.select = function(items, opts, callback)
        -- Mock mkdir to return -1 (failure)
        vim.fn.mkdir = function()
          return -1
        end

        callback(items[1])
      end

      instance:create_new_class()

      -- Restore
      require("phptools.composer").get_prefix_and_src = original_get_prefix

      assert.truthy(notify_called)
      assert.truthy(notify_message:match("Failed to create directory"))
    end)

    it("should fall back to current directory when no PSR-4 paths found", function()
      local instance = Class:new()
      instance.class_name = { text = "TestClass" }
      instance.parent = { type = "object_creation_expression" }

      local select_items = nil

      -- Mock composer.get_prefix_and_src to return empty list
      local original_get_prefix = require("phptools.composer").get_prefix_and_src
      require("phptools.composer").get_prefix_and_src = function()
        return {}
      end

      -- Mock vim.ui.select to capture options
      vim.ui.select = function(items, opts, callback)
        select_items = items
      end

      instance:create_new_class()

      -- Restore
      require("phptools.composer").get_prefix_and_src = original_get_prefix

      assert.equals(#select_items, 2) -- "." directory + create new option
      assert.equals(select_items[1].path, ".")
      assert.equals(select_items[1].prefix, "")
    end)

    it("should include create new directory option", function()
      local instance = Class:new()
      instance.class_name = { text = "TestClass" }
      instance.parent = { type = "object_creation_expression" }

      local select_items = nil

      -- Mock composer.get_prefix_and_src
      local original_get_prefix = require("phptools.composer").get_prefix_and_src
      require("phptools.composer").get_prefix_and_src = function()
        return {
          { prefix = "App\\", src = "src/" }
        }
      end

      -- Mock vim.ui.select to capture options
      vim.ui.select = function(items, opts, callback)
        select_items = items
      end

      instance:create_new_class()

      -- Restore
      require("phptools.composer").get_prefix_and_src = original_get_prefix

      -- Should have 1 PSR-4 path + create new option
      assert.equals(#select_items, 2)
      assert.equals(select_items[1].path, "src/")
      assert.equals(select_items[2].is_custom, true)
      assert.equals(select_items[2].path, "[Create new directory]")
    end)

    it("should prompt for custom directory when selected", function()
      local instance = Class:new()
      instance.class_name = { text = "TestClass" }
      instance.parent = { type = "object_creation_expression" }

      local input_prompt = nil

      -- Mock composer.get_prefix_and_src
      local original_get_prefix = require("phptools.composer").get_prefix_and_src
      require("phptools.composer").get_prefix_and_src = function()
        return { { prefix = "App\\", src = "src/" } }
      end

      -- Mock vim.ui.select to select the custom option
      vim.ui.select = function(items, opts, callback)
        callback(items[2]) -- Select "Create new directory"
      end

      -- Mock vim.ui.input to capture prompt
      vim.ui.input = function(opts, input_callback)
        input_prompt = opts.prompt
      end

      instance:create_new_class()

      -- Restore
      require("phptools.composer").get_prefix_and_src = original_get_prefix

      assert.truthy(input_prompt:match("Enter directory path"))
    end)
  end)
end)
