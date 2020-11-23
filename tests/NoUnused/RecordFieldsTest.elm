module NoUnused.RecordFieldsTest exposing (all)

import Dependencies.ElmCore
import NoUnused.RecordFields exposing (rule)
import Review.Project as Project exposing (Project)
import Review.Test
import Test exposing (Test, describe, test)


all : Test
all =
    describe "NoUnused.RecordFields"
        [ test "should not report unused variables" <|
            \() ->
                """module A exposing (b)
a = {foo=1, unused=2}
b = let c = {foo=1}
    in 1
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectNoErrors
        , test "should report an unused field" <|
            \() ->
                """module A exposing (b)
a : {foo:Int,unused:Int}
a = {foo=1, unused=2}
b = a.foo
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectErrors
                        [ Review.Test.error
                            { message = "Unused field `unused`"
                            , details = [ "REPLACEME" ]
                            , under = "unused"
                            }
                            |> Review.Test.atExactly { start = { row = 3, column = 13 }, end = { row = 3, column = 19 } }
                        ]
        , test "should not report if value is used with an unknown function" <|
            \() ->
                """module A exposing (b)
a = {foo=1, unused=2}
b = thing a
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectNoErrors
        , test "should not report if value is exposed as part of the module (exposing (..))" <|
            \() ->
                """module A exposing (..)
a = {foo=1, unused=2}
b = a.foo
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectNoErrors
        , test "should not report if value is exposed as part of the module (exposing explicitly)" <|
            \() ->
                """module A exposing (a, b)
a = {foo=1, unused=2}
b = a.foo
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectNoErrors
        , test "TODO should not check when value is a type alias" <|
            \() ->
                """module A exposing (b, TypeAlias)
type alias TypeAlias = {foo:Int,bar:Int}
a : TypeAlias
a = {foo=1, bar=2}
b = a.foo
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectNoErrors
        , test "TODO should not report if record is hidden behind a function" <|
            \() ->
                """module A exposing (b)
a argument = {foo=1, unused=2}
b = a.foo
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectNoErrors
        , test "should report unused fields of argument (using record access)" <|
            \() ->
                """module A exposing (a)
a : {foo:Int, unused:Int} -> Int
a arg = arg.foo
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectErrors
                        [ Review.Test.error
                            { message = "Unused field `unused`"
                            , details = [ "REPLACEME" ]
                            , under = "unused"
                            }
                        ]
        , test "should report unused fields of argument (with parens)" <|
            \() ->
                """module A exposing (a)
a : {foo:Int, unused:Int} -> Int
a (arg) = arg.foo
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectErrors
                        [ Review.Test.error
                            { message = "Unused field `unused`"
                            , details = [ "REPLACEME" ]
                            , under = "unused"
                            }
                        ]
        , test "should report unused fields of argument (with as pattern)" <|
            \() ->
                """module A exposing (a)
a : {foo:Int, unused:Int} -> Int
a (_ as arg) = arg.foo
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectErrors
                        [ Review.Test.error
                            { message = "Unused field `unused`"
                            , details = [ "REPLACEME" ]
                            , under = "unused"
                            }
                        ]
        , test "should report unused fields of argument (with as pattern when using the left pattern)" <|
            \() ->
                """module A exposing (a)
a : {foo:Int, bar:Int,unused:Int} -> Int
a ({bar} as arg) = arg.foo
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectErrors
                        [ Review.Test.error
                            { message = "Unused field `unused`"
                            , details = [ "REPLACEME" ]
                            , under = "unused"
                            }
                        ]
        , test "should report unused fields of argument when argument is generic" <|
            \() ->
                """module A exposing (a)
a : {var|foo:Int, unused:Int} -> Int
a arg = arg.foo
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectErrors
                        [ Review.Test.error
                            { message = "Unused field `unused`"
                            , details = [ "REPLACEME" ]
                            , under = "unused"
                            }
                        ]
        , test "should report unused fields of argument (using destructuring)" <|
            \() ->
                """module A exposing (a)
a : {foo:Int, unused:Int} -> Int
a {foo} = arg.foo
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectErrors
                        [ Review.Test.error
                            { message = "Unused field `unused`"
                            , details = [ "REPLACEME" ]
                            , under = "unused"
                            }
                        ]
        , test "should not report when a generic record input type is found again in the output type" <|
            \() ->
                -- NOTE: I was never able to make this test fail, but I could find this kind of error
                -- being reported in real codebases
                """module A exposing (a)
a : { a | thing : Bool } -> { a | thing : Bool }
a value =
    { value | thing = True }
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectNoErrors
        , test "should report an unused field in a let function" <|
            \() ->
                """module A exposing (a)
a =
  let
    b : {foo:Int,unused:Int}
    b = {foo=1, unused=2}
  in b.foo
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectErrors
                        [ Review.Test.error
                            { message = "Unused field `unused`"
                            , details = [ "REPLACEME" ]
                            , under = "unused"
                            }
                            |> Review.Test.atExactly { start = { row = 5, column = 17 }, end = { row = 5, column = 23 } }
                        ]
        , test "should not mix two let declarations that are in different locations" <|
            \() ->
                """module A exposing (a)
a =
  let
    b : {foo:Int,bar:Int}
    b = {foo=1, bar=2}
  in b.foo
c =
  let
    b : {foo:Int,bar:Int}
    b = {foo=1, bar=2}
  in b.bar
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectErrors
                        [ Review.Test.error
                            { message = "Unused field `bar`"
                            , details = [ "REPLACEME" ]
                            , under = "bar"
                            }
                            |> Review.Test.atExactly { start = { row = 5, column = 17 }, end = { row = 5, column = 20 } }
                        , Review.Test.error
                            { message = "Unused field `foo`"
                            , details = [ "REPLACEME" ]
                            , under = "foo"
                            }
                            |> Review.Test.atExactly { start = { row = 10, column = 10 }, end = { row = 10, column = 13 } }
                        ]
        , test "should not report unused field if it is used in a let expression below" <|
            \() ->
                """module A exposing (a)
a : {foo:Int,bar:Int} -> Int
a b =
  let c = b.foo
  in
  let d = b.bar
  in
  b + d
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectNoErrors
        , test "should not report unused field if it is used in a let expression below 2" <|
            \() ->
                """module A exposing (a)
foo : { used : Bool, thing : Thing } -> Bool
foo params =
    case params.thing of
        _ ->
            let _ = 1
            in params.used
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectNoErrors
        , test "should report an unused field in a let destructuration" <|
            \() ->
                """module A exposing (a)
a =
  let
    {foo} = {foo=1, unused=2}
  in foo
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectErrors
                        [ Review.Test.error
                            { message = "Unused field `unused`"
                            , details = [ "REPLACEME" ]
                            , under = "unused"
                            }
                            |> Review.Test.atExactly { start = { row = 4, column = 21 }, end = { row = 4, column = 27 } }
                        ]
        , test "should not report a field when used with a `.field` accessor function" <|
            \() ->
                """module A exposing (b)
a : {foo:Int,unused:Int}
a = {foo=1, unused=2}
b = .foo a
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectErrors
                        [ Review.Test.error
                            { message = "Unused field `unused`"
                            , details = [ "REPLACEME" ]
                            , under = "unused"
                            }
                            |> Review.Test.atExactly { start = { row = 3, column = 13 }, end = { row = 3, column = 19 } }
                        ]
        , test "should not report a field when used with a function that uses only a select number of fields" <|
            \() ->
                """module A exposing (b)
a : {foo:Int,unused:Int}
a = {foo=1, unused=2}
b = getFoo a

getFoo : { var | foo : Int } -> Int
getFoo data =
    data.foo
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectErrors
                        [ Review.Test.error
                            { message = "Unused field `unused`"
                            , details = [ "REPLACEME" ]
                            , under = "unused"
                            }
                            |> Review.Test.atExactly { start = { row = 3, column = 13 }, end = { row = 3, column = 19 } }
                        ]
        , test "should not report a field when used with a function that uses only a select number of fields, not as the first argument" <|
            \() ->
                """module A exposing (b)
a : {foo:Int,unused:Int}
a = {foo=1, unused=2}
b = getFoo 1 2 a

getFoo : Int -> Int -> { var | foo : Int } -> Int
getFoo _ _ data =
    data.foo
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectErrors
                        [ Review.Test.error
                            { message = "Unused field `unused`"
                            , details = [ "REPLACEME" ]
                            , under = "unused"
                            }
                            |> Review.Test.atExactly { start = { row = 3, column = 13 }, end = { row = 3, column = 19 } }
                        ]
        , Test.skip <|
            test "should report a field when only used in the context of re-assigning it to itself" <|
                \() ->
                    """module A exposing (b)
a : {foo:Int,unused:Int}
a = {foo=1, unused=2}
b = { a | unused = unused + 1 }
c = a.foo
"""
                        |> Review.Test.runWithProjectData project rule
                        |> Review.Test.expectErrors
                            [ Review.Test.error
                                { message = "Unused field `unused`"
                                , details = [ "REPLACEME" ]
                                , under = "unused"
                                }
                                |> Review.Test.atExactly { start = { row = 3, column = 13 }, end = { row = 3, column = 19 } }
                            ]
        , test "should report an unused field from a literal record passed to a function directly" <|
            \() ->
                """module A exposing (b)
b = getFoo {foo=1, unused=2}

getFoo : { var | foo : Int } -> Int
getFoo data =
    data.foo
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectErrors
                        [ Review.Test.error
                            { message = "Unused field `unused`"
                            , details = [ "REPLACEME" ]
                            , under = "unused"
                            }
                        ]
        , test "should report an unused field from a literal record passed to a function through parens" <|
            \() ->
                """module A exposing (b)
b = getFoo ({foo=1, unused=2})

getFoo : { var | foo : Int } -> Int
getFoo data =
    data.foo
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectErrors
                        [ Review.Test.error
                            { message = "Unused field `unused`"
                            , details = [ "REPLACEME" ]
                            , under = "unused"
                            }
                        ]
        , Test.skip <|
            test "should report an unused field when going through a binary operation" <|
                \() ->
                    """module A exposing (b)
b = {foo=1, unused=2} |> .foo
"""
                        |> Review.Test.runWithProjectData project rule
                        |> Review.Test.expectErrors
                            [ Review.Test.error
                                { message = "Unused field `unused`"
                                , details = [ "REPLACEME" ]
                                , under = "unused"
                                }
                            ]
        , test "should report an unused field when the value corresponds to an unused generic argument of the function that uses it" <|
            \() ->
                """module A exposing (b)
a = {foo=1, unused=2}
b = a.foo
c = foo a

foo : a -> Int
foo _ = 1
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectErrors
                        [ Review.Test.error
                            { message = "Unused field `unused`"
                            , details = [ "REPLACEME" ]
                            , under = "unused"
                            }
                        ]
        , test "should report an unused field when the value corresponds to a generic argument of the function that uses it that can be found again" <|
            \() ->
                """module A exposing (b)
a = {foo=1, unused=2}
b = a.foo
c = thing (identity a)
"""
                    |> Review.Test.runWithProjectData project rule
                    |> Review.Test.expectNoErrors
        ]


project : Project
project =
    Project.new
        |> Project.addDependency Dependencies.ElmCore.dependency
