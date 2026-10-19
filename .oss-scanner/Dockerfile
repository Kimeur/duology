# Build environment for Anthropic's OSS Scanner (https://github.com/anthropics/oss-scanner).
# Duology is Claude Code skills (Markdown) plus Python and shell tooling. The Swift
# samples need Xcode and can't build on Linux; everything that runs on a user's
# machine and takes outside input is Python or shell, and runs here.
FROM debian:bookworm
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates git python3 python3-yaml bash jq \
    && rm -rf /var/lib/apt/lists/*

# scanner contract: the checkout lives inside the image, at /src
COPY . /src
WORKDIR /src

# Same checks as CI (.github/workflows/validate.yml). Failures are reported, not fatal.
RUN (python3 scripts/validate-skills.py --portable --strict \
     && python3 scripts/check-manifests.py \
     && python3 -m unittest discover plugins/duology-ship/skills/duo-lint/tests \
     && python3 -m unittest discover plugins/duology-ship/skills/duo-pose-matrix/tests \
     && python3 -m unittest discover -s scripts/tests \
     && python3 -m unittest discover -s evals/lib \
     && python3 plugins/duology-ship/skills/duo-lint/scripts/duo-lint.py --strict samples plugins/duology-recipes) \
    || echo "WARNING: some Duology checks failed"
