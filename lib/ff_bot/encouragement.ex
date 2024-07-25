defmodule FFBot.Encouragement do
  @moduledoc """
  Encouragement functions for our Comrades.
  """

  # Fractional percentage of how often the bot will generate a supportive
  # comment on merge.
  @support_a_comrade_margin 0.01
  # Fractional percentage of how often the bot will generate an encouraging
  # comment on conflicts.
  @encourage_a_comrade_threshold 0.01

  defp supports_comrades? do
    Application.get_env(:ff_bot, :disable_propaganda?) == nil
  end

  defp should_generate_supportive_comment? do
    :rand.uniform() < @support_a_comrade_margin
  end

  defp should_generate_encouraging_comment? do
    :rand.uniform() < @encourage_a_comrade_threshold
  end

  @doc """
  On a slim chance, generate a comment that expresses appreciation in the comrade's work.
  """
  def maybe_supportive_comment do
    if supports_comrades?() && should_generate_supportive_comment?() do
      ". Glory to Arstotzka!"
    else
      ""
    end
  end

  @doc """
  On a slim chance, generate a comment that expresses encouragement for the comrade to work better.
  """
  def maybe_encouraging_comment do
    if supports_comrades?() && should_generate_encouraging_comment?() do
      ". Any negligence will result in swift punishment."
    else
      ""
    end
  end
end
