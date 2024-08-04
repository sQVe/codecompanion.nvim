local assert = require("luassert")
local mock = require("luassert.mock")

local codecompanion = require("codecompanion")

local Chat
local adapter = {
  name = "TestAdapter",
  url = "https://api.openai.com/v1/chat/completions",
  headers = {
    content_type = "application/json",
  },
  parameters = {
    stream = true,
  },
  callbacks = {
    form_parameters = function()
      return {}
    end,
    form_messages = function()
      return {}
    end,
    is_complete = function()
      return false
    end,
  },
  schema = {},
}

describe("Chat", function()
  before_each(function()
    package.loaded["codecompanion.tools.code_runner"] = {
      schema = {},
      system_prompt = function(schema)
        return "baz"
      end,
    }

    codecompanion.setup({
      strategies = {
        chat = {
          roles = {
            llm = "assistant",
            user = "foo",
          },
        },

        agent = {
          adapter = "openai",
          tools = {
            ["code_runner"] = {
              callback = "tools.code_runner",
              description = "Agent to run code generated by the LLM",
            },
            opts = {
              system_prompt = "bar",
            },
          },
        },
      },
      opts = {
        system_prompt = "foo",
      },
    })

    Chat = require("codecompanion.strategies.chat").new({
      context = { bufnr = 1, filetype = "lua" },
      adapter = require("codecompanion.adapters").use(adapter),
    })
  end)

  describe(":preprocess_messages", function()
    it("system prompt is added first", function()
      local messages = {
        { role = "user", content = "Hello" },
        { role = "assistant", content = "Hi there!" },
      }

      local result = Chat:preprocess_messages(messages)

      assert.are.same(3, #result) -- 2 original messages + 1 system prompt
      assert.are.same("system", result[1].role)
      assert.are.same("foo", result[1].content)
      assert.are.same("user", result[2].role)
      assert.are.same("Hello", result[2].content)
      assert.are.same("assistant", result[3].role)
      assert.are.same("Hi there!", result[3].content)
    end)

    it("agent system prompts are added next", function()
      local messages = {
        { role = "user", content = "@code_runner can you run some code for me?" },
      }

      local result = Chat:preprocess_messages(messages)

      assert.are.same(4, #result)
      assert.are.same("system", result[1].role)
      assert.are.same("foo", result[1].content)
      assert.are.same("system", result[2].role)
      assert.are.same("bar", result[2].content)
      assert.are.same("system", result[3].role)
      assert.are.same("\n\nbaz", result[3].content)
    end)
  end)
end)