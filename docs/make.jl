using Documenter
using Documenter: Remotes

using DatashieldInterface

makedocs(;
    modules=[DatashieldInterface],
    authors="Hugo Solleder <hugo.solleder@epfl.ch> and contributors",
    repo=Remotes.GitHub("obiba", "DatashieldInterface.jl"),
    sitename="DatashieldInterface.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://obiba.github.io/DatashieldInterface.jl",
        assets=String[],
    ),
    warnonly=[:missing_docs],
    pages=[
        "Home" => "index.md",
        "Contributing" => "90-contributing.md",
        "Developer Docs" => "91-developer.md",
        "API Reference" => "api.md",
    ],
)

deploydocs(; repo="github.com/obiba/DatashieldInterface.jl", devbranch="main")
