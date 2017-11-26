defmodule DBFS.Block do
  use DBFS.Repo.Schema

  import DBFS.Block.Validations

  alias DBFS.Crypto
  alias DBFS.Block
  alias DBFS.Blockchain


  @zero %{
    type:   :zero,
    pvtkey: Application.get_env(:dbfs, :zero_key),
    pubkey: Crypto.public_key(Application.get_env(:dbfs, :zero_key)),
    hash:   Crypto.sha256(Application.get_env(:dbfs, :zero_cookie)),
  }

  @fields_required [:type, :data, :prev, :hash, :creator, :signature, :timestamp]
  @derive {Poison.Encoder, only: [:id | @fields_required]}


  schema "blocks" do
    field :type,      Enums.Block.Type
    field :data,      :map, default: %{}
    field :prev,      :string
    field :hash,      :string
    field :creator,   :string
    field :signature, :string
    field :timestamp, :naive_datetime
  end


  def changeset(schema, params \\ %{}) do
    schema
    |> cast(params, @fields_required)
    |> validate_required(@fields_required)
    |> validate_data
    |> validate_crypto
  end


  @doc "Get last block"
  def last do
    Block
    |> Query.last
    |> Repo.one
  end

  def paged(opts) do
    Block
    |> Query.order_by(desc: :id)
    |> Pager.paginate(opts)
  end

  defoverridable [all: 0]
  def all do
    Block
    |> Query.order_by(desc: :id)
    |> Repo.all
  end


  defoverridable [get: 1]
  def get(hash) do
    Block
    |> Query.where([b], b.hash == ^hash)
    |> Repo.one
  end


  @doc "Block Zero a.k.a starting point of the blockchain"
  def zero do
    block =
      %Block{
        data: %{},
        type: @zero.type,
        prev: @zero.hash,
        creator: @zero.pubkey,
        timestamp: NaiveDateTime.utc_now()
      }

    block
    |> Crypto.sign!(@zero.pvtkey)
    |> Crypto.hash!
  end


  @doc "Create a new Block from a Blockchain or an existing one"
  def new(%Block{hash: hash}, params \\ %{}) do
    params =
      params
      |> Enum.into(%{})
      |> Map.put(:prev, hash)
      |> Map.put(:timestamp, NaiveDateTime.utc_now())

    changeset(%Block{}, params)
  end


end
