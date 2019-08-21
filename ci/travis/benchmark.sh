#!/bin/bash

set -ev

julia -e '
    import Pkg;
    Pkg.build("ModelSanitizer")
    '

mkdir -p $TRAVIS_BUILD_DIR/benchmark/benchmarkingenvironment
touch $TRAVIS_BUILD_DIR/benchmark/benchmarkingenvironment/Project.toml
cd $TRAVIS_BUILD_DIR/benchmark/benchmarkingenvironment

julia --project=. -e '
    import Pkg;
    Pkg.develop(Pkg.PackageSpec(path = ENV["TRAVIS_BUILD_DIR"]))
    '

julia --project=. -e '
    import Pkg;
    Pkg.add(
        [
            Pkg.PackageSpec(name="BenchmarkTools", version="0.4.2"),
            Pkg.PackageSpec(name="Coverage", version="0.9.2"),
            Pkg.PackageSpec(name="DataFrames", version="0.18.4"),
            Pkg.PackageSpec(name="MLJ", version="0.2.5"),
            Pkg.PackageSpec(name="MLJBase", version="0.2.3"),
            Pkg.PackageSpec(name="MLJModels", version="0.2.5"),
            Pkg.PackageSpec(name="MultivariateStats", version="0.6.0"),
            Pkg.PackageSpec(name="PkgBenchmark", version="0.2.2"),
            Pkg.PackageSpec(name="StatsBase", version="0.31.0"),
            Pkg.PackageSpec(name="StatsModels", version="0.6.2"),
            Pkg.PackageSpec(name="TimerOutputs", version="0.5.0"),
            Pkg.PackageSpec(name="GitHub", version="5.1.1"),
            ]
        )
    '

export CURRENT_GIT_BRANCH="$(git rev-parse --symbolic-full-name --abbrev-ref HEAD)"

echo "$CURRENT_GIT_BRANCH"

if [ "$CURRENT_GIT_BRANCH" == "master" ]; then
    echo "I AM on master"
else
    echo "I am NOT on master"
    git fetch origin master:master
fi

if [ "$CURRENT_GIT_BRANCH" == "staging" ]; then
    echo "I AM on staging"
else
    echo "I am NOT on staging"
fi

if [ "$CURRENT_GIT_BRANCH" == "trying" ]; then
    echo "I AM on trying"
else
    echo "I am NOT on trying"
fi

julia --project=. $TRAVIS_BUILD_DIR/benchmark/run.jl
