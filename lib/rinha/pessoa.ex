defmodule Pessoa do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query
  import Ex.Ecto.Changeset
  import Rinha.Pessoa.Query, only: [search_score: 5]

  @typedoc false
  @type t :: %Pessoa{
          id: Ecto.UUID.t(),
          nome: String.t(),
          apelido: String.t(),
          data_nascimento: Date.t(),
          stack: [String.t(), ...] | nil
        }

  @primary_key false
  @derive {Jason.Encoder, only: [:id, :nome, :apelido, :data_nascimento, :stack]}
  schema "pessoas" do
    field :id, Ecto.UUID, autogenerate: true, primary_key: true
    field :nome, :string
    field :apelido, :string
    field :data_nascimento, :date
    field :stack, {:array, :string}
  end

  @required_error_msg "campo obrigatório"

  @doc """
  Returna um `Ecto.Changeset` com as alterações feitas em um model
  `Pessoa`.
  """
  @spec changeset(t(), map) :: Ecto.Changeset.t()

  @dup_nick_error_msg "já existe uma pessoa com esse apelido"
  @alphabet_error_msg "apenas letras e espaços são permitidos"
  @min_char_error_msg "deve conter no mínimo %{count} caracteres"
  @max_char_error_msg "deve conter no máximo %{count} caracteres"

  @accents "àèìòùÀÈÌÒÙáéíóúýÁÉÍÓÚÝâêîôûÂÊÎÔÛãñõÃÑÕäëïöüÿÄËÏÖÜŸçÇ"
  @name_pattern ~r/^[a-zA-Z#{@accents}\s]+$/

  def changeset(pessoa, params \\ %{}) do
    pessoa
    |> cast(params, [:nome, :apelido, :data_nascimento, :stack])
    |> validate_required([:nome, :apelido, :data_nascimento], message: @required_error_msg)
    |> validate_length(:nome, min: 3, message: @min_char_error_msg)
    |> validate_length(:nome, max: 75, message: @max_char_error_msg)
    |> validate_format(:nome, @name_pattern, message: @alphabet_error_msg)
    |> validate_length(:apelido, max: 32, message: @max_char_error_msg)
    |> unique_constraint(:apelido, message: @dup_nick_error_msg)
    |> validate_each(:stack, validate_length(max: 10, message: @max_char_error_msg))
  end

  @doc """
  Query builder para o model `Pessoa`.
  """
  @spec pessoas_query([{atom, term}, ...]) :: Ecto.Queryable.t()

  def pessoas_query(filters)
      when is_list(filters),
      do: filter(__MODULE__, filters)

  @reasonable_score 0.15

  defp filter(query, []), do: query
  defp filter(query, [{:id, id} | tail]), do: where(query, [p], p.id == ^id) |> filter(tail)

  defp filter(query, [{:q, str} | tail]) do
    query
    |> where([p], search_score(p.nome, p.apelido, p.stack, ^@reasonable_score, ^str) > ^@reasonable_score)
    |> order_by([p], desc: search_score(p.nome, p.apelido, p.stack, ^@reasonable_score, ^str), asc: p.nome)
    |> filter(tail)
  end
end
