#!/usr/bin/env bats

setup(){
    TMPDIR="$(mktemp -d --suffix _pynixify_tests)"
    cd "${TMPDIR}"
}

teardown(){
    rm -rf "${TMPDIR}"
}

@test "sampleproject" {
    pynixify sampleproject==1.3.1
    nix-build pynixify/nixpkgs.nix -A python3.pkgs.sampleproject
    ./result/bin/sample | grep 'Call your main'

    # Temporary files should be removed
    echo ${TMPDIR}/pynixify_*
    [[ -z "$(find "${TMPDIR}" -maxdepth 1 -name 'pynixify_*' -print -quit)" ]]
    grep "A sample Python project" pynixify/packages/sampleproject/default.nix
}

@test "sampleproject in python 3.8" {
    pynixify sampleproject==1.3.1
    nix-build pynixify/nixpkgs.nix -A python38.pkgs.sampleproject
    ./result/bin/sample | grep 'Call your main'
}

@test "sampleproject in python 2.7" {
    pynixify sampleproject==1.3.1
    nix-build pynixify/nixpkgs.nix -A python27.pkgs.sampleproject
    ./result/bin/sample | grep 'Call your main'
}

@test "sampleproject-local" {
    git clone https://github.com/pypa/sampleproject
    cd sampleproject
    sed -i 's/your/my/' src/sample/__init__.py
    pynixify --local sampleproject
    nix-build pynixify/nixpkgs.nix -A python3.pkgs.sampleproject
    ./result/bin/sample | grep 'Call my main'
}

@test "faraday-agent-dispatcher" {
    pynixify faraday-agent-dispatcher
    nix-build pynixify/nixpkgs.nix -A python3.pkgs.faraday-agent-dispatcher
    grep 'fetchPypi {' pynixify/packages/faraday-agent-dispatcher/default.nix
    ./result/bin/faraday-dispatcher --help
}

@test "pin nixpkgs" {
    NIXPKGS_COMMIT=f1f5247103494195d00afd0b0f4ae789dedfd0e4
    pynixify flask \
        --nixpkgs "https://github.com/nixos/nixpkgs/archive/$NIXPKGS_COMMIT.tar.gz"
    cat pynixify/nixpkgs.nix
    nix-build pynixify/nixpkgs.nix -A python3.pkgs.flask
    if ! ./result/bin/flask --version | grep 'Flask 1.0.4'
    then
        echo Invalid Flask version:
        ./result/bin/flask --version
        exit 1
    fi
}

@test "pin nixpkgs 2" {
    # This tests that the pinned nixpkgs is used not only in the generated
    # expression, but also when discovering nix packages
    NIXPKGS_COMMIT=f1f5247103494195d00afd0b0f4ae789dedfd0e4
    pynixify psycopg2==2.7.7 \
        --nixpkgs "https://github.com/nixos/nixpkgs/archive/$NIXPKGS_COMMIT.tar.gz"
    if [[ -f pynixify/packages/psycopg2/default.nix ]]; then
        echo "Didn't use nixpkgs version of psycopg2"
        exit 1
    fi
    nix-build pynixify/nixpkgs.nix -A python3.pkgs.psycopg2
}

@test "--output-dir" {
    pynixify sampleproject==1.3.1 -o my-pynixify-dir
    nix-build my-pynixify-dir/nixpkgs.nix -A python3.pkgs.sampleproject
    ./result/bin/sample | grep 'Call your main'
}

@test "no --load-test-requirements-for" {
    pynixify pytest 'textwrap3==0.9.1'
    ! grep 'pytest' pynixify/packages/textwrap3/default.nix
    nix-build pynixify/nixpkgs.nix -A python3.pkgs.textwrap3
}

@test "--load-test-requirements-for" {
    pynixify --tests=teXtwrap3 'textwrap3==0.9.1'
    nix-build pynixify/nixpkgs.nix -A python3.pkgs.textwrap3
    nix-store -qR result | { ! grep pytest; }
    grep 'pytest' pynixify/packages/textwrap3/default.nix
    git clone https://github.com/jonathaneunice/textwrap3
    cd textwrap3
    git checkout f6cd3e05be255011a5ef1bd442574d104a0050cb
    nix-shell ../pynixify/nixpkgs.nix -A python3.pkgs.textwrap3 --command py.test
}

@test "--load-all-test-requirements" {
    pynixify --all-tests 'textwrap3==0.9.1'
    nix-build pynixify/nixpkgs.nix -A python3.pkgs.textwrap3
    nix-store -qR result | { ! grep pytest; }
    grep 'pytest' pynixify/packages/textwrap3/default.nix
    git clone https://github.com/jonathaneunice/textwrap3
    cd textwrap3
    git checkout f6cd3e05be255011a5ef1bd442574d104a0050cb
    nix-shell ../pynixify/nixpkgs.nix -A python3.pkgs.textwrap3 --command py.test
}

@test "--ignore-test-requirements-for" {
    # filedepot depends on boto3, which depends on botocore, which isn't
    # compatible with the nixpkgs version of docutils (actually, it is, but it
    # requires patching the source)
    pynixify --all-tests --ignore-tests=filedepot \
        docutils filedepot
    nix-build pynixify/nixpkgs.nix -A python3.pkgs.filedepot
}
