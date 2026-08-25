#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# Starts a scenario with a repository at Send v3.4.27 which has already seen
# two releases of it (v3.4.27-0 and v3.4.27-1).
#
# The defaults file carries the traps this role's real one has: the Renovate
# annotation that has to stay attached to the version, and two variables
# derived from the version through Jinja. Neither derived variable may be
# picked up as the version - doing so would produce a literal `v{{-0` tag.
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/meta" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	cat > defaults/main.yml <<-'YAML'
		# renovate: datasource=docker depName=registry.gitlab.com/timvisee/send versioning=semver
		send_version: v3.4.27

		send_container_image: "{{ send_container_image_registry_prefix }}timvisee/send:{{ send_container_image_tag }}"
		send_container_image_tag: "{{ send_version }}"
		send_container_image_self_build_repo_version: "{{ send_version if send_version != 'latest' else 'main' }}"
	YAML
	printf 'placeholder\n' > meta/main.yml
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/env.j2
	printf 'placeholder\n' > README.md
	mkdir -p molecule/default
	printf 'placeholder\n' > molecule/default/verify.yml

	git add -A
	git commit -qm 'Initial commit'

	local release_number
	for release_number in 0 1; do
		git tag "v3.4.27-$release_number"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_version="sed -i 's|^send_version: v3.4.27|send_version: v3.4.28|' defaults/main.yml"
revert_version="sed -i 's|^send_version: v3.4.28|send_version: v3.4.27|' defaults/main.yml"
unprefixed_version="sed -i 's|^send_version: v3.4.27|send_version: 3.4.28|' defaults/main.yml"
pin_image_tag="sed -i 's|^send_container_image_tag: .*|send_container_image_tag: v9.9.9|' defaults/main.yml"
edit_meta="printf 'a platform\n' >> meta/main.yml"
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/env.j2"
edit_readme="printf 'documentation\n' >> README.md"
edit_molecule="printf 'an assert\n' >> molecule/default/verify.yml"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The two merge orders below apply the same updates and must each end up with
# every update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v3.4.28-0 "$(merge "$bump_version")"
expect 'task edit'    v3.4.28-1 "$(merge "$edit_task")"
expect 'template'     v3.4.28-2 "$(merge "$edit_template")"
expect 'meta'         v3.4.28-3 "$(merge "$edit_meta")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v3.4.27-2 "$(merge "$edit_task")"
expect 'version bump' v3.4.28-0 "$(merge "$bump_version")"

scenario 'Commits that do not affect the role'
expect 'README'   ''        "$(merge "$edit_readme")"
expect 'Molecule' ''        "$(merge "$edit_molecule")"
expect 'a script' ''        "$(merge "$edit_script")"
expect 'a task'   v3.4.27-2 "$(merge "$edit_task")"

scenario 'Release numbers past 9'
for release_number in 2 3 4 5 6 7 8 9 10; do
	git tag "v3.4.27-$release_number"
done
expect 'a task' v3.4.27-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_version" > /dev/null
# The role is now identical to what v3.4.27-1 already published, so there is
# nothing new to release.
expect 'a revert' ''        "$(merge "$revert_version")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_version" > /dev/null
expect 'a revert' v3.4.27-2 "$(merge "$revert_version && $edit_task")"

# Send's version values carry a leading `v`, but the tag must not gain a second
# one if that convention ever changes.
scenario 'A version value without the leading v still yields a v-prefixed tag'
expect 'version bump' v3.4.28-0 "$(merge "$unprefixed_version")"

# `send_container_image_tag` is normally `{{ send_version }}`. Pinning it to a
# literal is the shape of change that a less careful match would follow.
scenario 'A pinned image tag is not mistaken for the version'
expect 'pinned tag' v3.4.27-2 "$(merge "$pin_image_tag")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
