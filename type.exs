[
  # find these files
  include: [
    "lib/example/**/*.ex",
    "lib/ex_type.ex",
    "test/**/*_test_case.ex"
  ],

  # exclude these files
  # exclude: ["lib/*.ex", "lib/ex_type/**/*.ex", "lib/mix/**/*.ex"],

  # add some extra typespecs for this project
  typespec: %{},
  debug: true
]
