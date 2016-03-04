defmodule ExMachina do
  @moduledoc """
  Defines functions for generating data

  In depth examples are in the [README](README.html)
  """

  defmodule UndefinedFactoryError do
    @moduledoc """
    Error raised when trying to build or create a factory that is undefined.
    """

    defexception [:message]

    def exception(factory_name) do
      message =
        """
        No factory defined for #{inspect factory_name}.

        Please check for typos or define your factory:

            def factory(#{inspect factory_name}) do
              ...
            end
        """
      %UndefinedFactoryError{message: message}
    end
  end

  defmodule UndefinedSave do
    @moduledoc """
    Error raised when trying to call create and save_record/1 is
    not defined.
    """

    defexception [:message]

    def exception do
      %UndefinedSave{
        message: "Define save_record/1. See docs for ExMachina.save_record/1."
      }
    end
  end

  use Application

  def start(_type, _args), do: ExMachina.Sequence.start_link

  defmacro __using__(_opts) do
    quote do
      @before_compile unquote(__MODULE__)

      import ExMachina, only: [sequence: 1, sequence: 2]

      def build(factory_name, attrs \\ %{}) do
        ExMachina.build(__MODULE__, factory_name, attrs)
      end

      def build_pair(factory_name, attrs \\ %{}) do
        ExMachina.build_pair(__MODULE__, factory_name, attrs)
      end

      def build_list(number_of_factories, factory_name, attrs \\ %{}) do
        ExMachina.build_list(__MODULE__, number_of_factories, factory_name, attrs)
      end
    end
  end

  @doc """
  Shortcut for creating unique values. Similar to sequence/2

  For more customization of the generated string, see ExMachina.sequence/2

  ## Examples

      def factory(:comment) do
        %{
          # Will generate "Comment Title 0" then "Comment Title 1", etc.
          title: sequence("Comment Title")
        }
      end
  """
  def sequence(name), do: ExMachina.Sequence.next(name)

  @doc """
  Create sequences for generating unique values

  ## Examples

      def factory(:user) do
        %{
          # Will generate "me-0@example.com" then "me-1@example.com", etc.
          email: sequence(:email, &"me-\#{&1}@foo.com")
        }
      end
  """
  def sequence(name, formatter), do: ExMachina.Sequence.next(name, formatter)

  @doc """
  Builds a factory with the passed in factory_name and attrs

  ## Example

      def factory(:user) do
        %{name: "John Doe", admin: false}
      end

      # Returns %{name: "John Doe", admin: true}
      build(:user, admin: true)
  """
  def build(module, factory_name, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})
    module.factory(factory_name) |> do_merge(attrs)
  end

  defp do_merge(%{__struct__: _} = record, attrs) do
    struct!(record, attrs)
  end
  defp do_merge(record, attrs) do
    Map.merge(record, attrs)
  end

  @doc """
  Builds and returns 2 records with the passed in factory_name and attrs

  ## Example

      # Returns a list of 2 users
      build_pair(:user)
  """
  def build_pair(module, factory_name, attrs \\ %{}) do
    ExMachina.build_list(module, 2, factory_name, attrs)
  end

  @doc """
  Builds and returns X records with the passed in factory_name and attrs

  ## Example

      # Returns a list of 3 users
      build_list(3, :user)
  """
  def build_list(module, number_of_factories, factory_name, attrs \\ %{}) do
    Enum.map(1..number_of_factories, fn(_) ->
      ExMachina.build(module, factory_name, attrs)
    end)
  end

  defmacro __before_compile__(_env) do
    # We are using line -1 because we don't want warnings coming from
    # save_record/1 when someone defines there own save_record/1 function.
    quote line: -1 do
      @doc """
      Raises a helpful error if no factory is defined.
      """
      def factory(factory_name) do
        raise UndefinedFactoryError, factory_name
      end

      @doc """
      Saves a record when `create` is called. Uses Ecto if using ExMachina.Ecto

      If using ExMachina.Ecto (`use ExMachina.Ecto, repo: MyApp.Repo`) this
      function will call `insert!` on the passed in repo.

      If you are not using ExMachina.Ecto, you must define a custom
      save_record/1 for saving the record.

      ## Examples

          defmodule MyApp.Factory do
            use ExMachina.Ecto, repo: MyApp.Repo

            def factory(:user) do
              %User{name: "John"}
            end
          end

          # Will build and save the record to the MyApp.Repo
          MyApp.Factory.create(:user)

          defmodule MyApp.JsonFactories do
            # Note, we are not using ExMachina.Ecto
            use ExMachina

            def factory(:user) do
              %User{name: "John"}
            end

            def save_record(record) do
              # Poison is a library for working with JSON
              Poison.encode!(record)
            end
          end

          # Will build and then return a JSON encoded version of the map
          MyApp.JsonFactories.create(:user)
      """
      def save_record(record) do
        raise UndefinedSave
      end
    end
  end
end
