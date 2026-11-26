#!/usr/bin/env node
// Postinstall for the claude wrapper package (name in ./package.json).
//
// Detects the platform, finds the matching native binary from optionalDependencies,
// and copies it over the bin/claude.exe placeholder. After this runs, `claude` execs
// the native binary directly — no Node.js process stays resident.
//
// If the native package isn't present (or this release channel doesn't ship one
// for the platform), prints instructions and leaves the placeholder stub in
// place; builds that set FAIL_ON_MISSING_NATIVE also exit 1 unless npm was
// run with --omit=optional (failInstallUnlessOptionalOmitted). Two installed
// copies, or one whose package.json cannot be read, exit 1 on both release
// channels, even with --omit=optional. Exit 1 fails the whole npm command (a
// project's install too) and makes npm print this script's output; on an
// update npm keeps the previous version.
// cli-wrapper.cjs (same directory) can be invoked manually as a fallback that
// locates the same platform package and spawns its binary.
//
// Platform detection, PLATFORMS and resolvePlatformPackageDir() are duplicated
// in cli-wrapper.cjs — keep in sync.

const { spawnSync } = require('child_process')
const {
  closeSync,
  copyFileSync,
  linkSync,
  openSync,
  unlinkSync,
  chmodSync,
  readFileSync,
  readSync,
  realpathSync,
  writeFileSync,
  statSync,
} = require('fs')
const { O_NONBLOCK, O_RDONLY } = require('fs').constants
const { arch } = require('os')
const path = require('path')

// Replaced at build time via sed. Keep the literals below as markers.
const PACKAGE_PREFIX = '@anthropic-ai/claude-code'
const BINARY_NAME = 'claude'
// Substituted to 'true' or 'false'; an unsubstituted marker reads as false.
const FAIL_ON_MISSING_NATIVE = 'false' === 'true'
const WRAPPER_NAME = require('./package.json').name
// A package.json longer than this is reported as unreadable, not parsed; a
// real platform package's is a few hundred bytes.
const MAX_MANIFEST_BYTES = 64 * 1024
// A named pipe (FIFO) in place of package.json must not block the open or
// read. POSIX only: Windows directories hold no FIFOs, and Bun there can
// define O_NONBLOCK as a value open() rejects.
const MANIFEST_OPEN_FLAGS =
  process.platform === 'win32' ? O_RDONLY : O_RDONLY | O_NONBLOCK

const PLATFORMS = {
  'darwin-arm64': { pkg: PACKAGE_PREFIX + '-darwin-arm64', bin: BINARY_NAME },
  'darwin-x64': { pkg: PACKAGE_PREFIX + '-darwin-x64', bin: BINARY_NAME },
  'linux-x64': { pkg: PACKAGE_PREFIX + '-linux-x64', bin: BINARY_NAME },
  'linux-arm64': { pkg: PACKAGE_PREFIX + '-linux-arm64', bin: BINARY_NAME },
  'linux-x64-musl': {
    pkg: PACKAGE_PREFIX + '-linux-x64-musl',
    bin: BINARY_NAME,
  },
  'linux-arm64-musl': {
    pkg: PACKAGE_PREFIX + '-linux-arm64-musl',
    bin: BINARY_NAME,
  },
  'linux-arm64-android': {
    pkg: PACKAGE_PREFIX + '-linux-arm64-android',
    bin: BINARY_NAME,
  },
  'linux-x64-android': {
    pkg: PACKAGE_PREFIX + '-linux-x64-android',
    bin: BINARY_NAME,
  },
  'win32-x64': {
    pkg: PACKAGE_PREFIX + '-win32-x64',
    bin: BINARY_NAME + '.exe',
  },
  'win32-arm64': {
    pkg: PACKAGE_PREFIX + '-win32-arm64',
    bin: BINARY_NAME + '.exe',
  },
}

function detectMusl() {
  if (process.platform !== 'linux') {
    return false
  }
  // process.report is available in Node ≥12; glibcVersionRuntime is absent on musl.
  // Faster than spawning `ldd` and avoids the ENOENT→musl false positive when ldd
  // isn't on PATH (minimal containers).
  const report =
    typeof process.report?.getReport === 'function'
      ? process.report.getReport()
      : null
  return report != null && report.header?.glibcVersionRuntime === undefined
}

function getPlatformKey() {
  const platform = process.platform
  let cpu = arch()
  if (platform === 'android') {
    return 'linux-' + cpu + '-android'
  }
  if (platform === 'linux') {
    return 'linux-' + cpu + (detectMusl() ? '-musl' : '')
  }
  // Rosetta 2: an x64 Node on Apple Silicon reports arch()==='x64'. Prefer the
  // native arm64 binary — the x64 build needs AVX, which Rosetta doesn't emulate.
  if (platform === 'darwin' && cpu === 'x64') {
    const r = spawnSync('sysctl', ['-n', 'sysctl.proc_translated'], {
      encoding: 'utf8',
    })
    if (r.stdout?.trim() === '1') {
      cpu = 'arm64'
    }
  }
  return platform + '-' + cpu
}

// Directory of the single installed copy of `pkg` at exactly `version`. Reads
// the two places a package manager puts it (beside this package in the
// enclosing node_modules, and in this package's own node_modules) and refuses
// to choose when it finds two copies, or one whose package.json cannot be
// read, so that a stray copy is reported instead of used. With no copy there,
// or inside a Yarn Plug'n'Play project, require.resolve finds it or throws.
function resolvePlatformPackageDir(pkg, version) {
  if (process.versions.pnp) {
    // process.versions.pnp is set for the whole process, also when another
    // project's Yarn Plug'n'Play runtime was preloaded through NODE_OPTIONS;
    // read the install locations only if that runtime disowns this file.
    let underPnp = true
    try {
      // Yarn's Plug'n'Play runtime (.pnp.cjs) adds findPnpApi to the built-in
      // 'node:module'; it returns null for a file outside every such project.
      // Not require('pnpapi'): a node_modules directory could supply that.
      const findPnpApi = require('node:module').findPnpApi
      underPnp =
        typeof findPnpApi !== 'function' || findPnpApi(__filename) != null
    } catch {
      // A runtime that throws here cannot say which files it manages; defer to it.
    }
    if (underPnp) {
      return path.dirname(require.resolve(pkg + '/package.json'))
    }
  }
  let packageDir = __dirname
  try {
    packageDir = realpathSync(__dirname)
  } catch {
    // Keep the unresolved path.
  }
  const parent = path.dirname(packageDir)
  const grandparent = path.dirname(parent)
  const candidates = []
  if (path.basename(parent) === 'node_modules') {
    candidates.push(path.join(parent, pkg))
  } else if (
    path.basename(parent).startsWith('@') &&
    path.basename(grandparent) === 'node_modules'
  ) {
    candidates.push(path.join(grandparent, pkg))
  }
  candidates.push(path.join(packageDir, 'node_modules', pkg))
  const found = []
  const realPaths = []
  for (const dir of candidates) {
    const manifestPath = path.join(dir, 'package.json')
    let real
    try {
      const fd = openSync(manifestPath, MANIFEST_OPEN_FLAGS)
      let text
      try {
        // Room for one byte past the limit, so a file of exactly
        // MAX_MANIFEST_BYTES passes and a longer one is caught.
        const buf = Buffer.alloc(MAX_MANIFEST_BYTES + 1)
        let length = 0
        let bytesRead
        do {
          bytesRead = readSync(fd, buf, length, buf.length - length, null)
          length += bytesRead
        } while (bytesRead > 0 && length < buf.length)
        if (length > MAX_MANIFEST_BYTES) {
          throw new Error(`larger than ${MAX_MANIFEST_BYTES} bytes`)
        }
        text = buf.toString('utf8', 0, length)
      } finally {
        closeSync(fd)
      }
      const manifest = JSON.parse(text)
      if (manifest?.name !== pkg || manifest?.version !== version) {
        continue
      }
      real = realpathSync(dir)
    } catch (err) {
      // No package.json here means no copy here (ENOENT, ENOTDIR). Any other
      // failure is a copy that cannot be checked, so nothing is chosen.
      if (err?.code === 'ENOENT' || err?.code === 'ENOTDIR') {
        continue
      }
      // An error code, not a message: JSON.parse's message quotes the file and
      // Node's can quote a symlink target, both of which a writer here chooses.
      const reason =
        err instanceof SyntaxError
          ? 'not valid JSON'
          : (err?.code ?? err?.message)
      const unreadable = new Error(
        `${manifestPath} cannot be read (${reason})`,
        { cause: err },
      )
      unreadable.code = 'EUNREADABLEPKG'
      unreadable.dir = dir
      unreadable.reason = reason
      throw unreadable
    }
    if (!realPaths.includes(real)) {
      realPaths.push(real)
      found.push(dir)
    }
  }
  if (found.length > 1) {
    const err = new Error(`${pkg}@${version} is installed in two places`)
    err.code = 'EDUPLICATEPKG'
    err.found = found
    throw err
  }
  return realPaths[0] ?? path.dirname(require.resolve(pkg + '/package.json'))
}

function placeBinary(src, dest) {
  // Try hardlink first (instant, zero extra disk for a ~500MB binary; src and
  // dest are both under node_modules/ so same-filesystem is the common case).
  // We attempt the link BEFORE touching dest — if src is missing (partial
  // extraction) the first linkSync throws ENOENT and the fallback stub stays.
  try {
    linkSync(src, dest)
  } catch (err) {
    if (err.code === 'EEXIST') {
      // Read the stub before unlinking so we can restore it if both link and
      // copy fail (ENOSPC, NFS error mid-500MB-copy). Only read if dest is
      // stub-sized — on re-install dest is the ~500MB binary.
      const stub = statSync(dest).size < 4096 ? readFileSync(dest) : null
      unlinkSync(dest)
      try {
        linkSync(src, dest)
      } catch {
        try {
          copyFileSync(src, dest)
        } catch (copyErr) {
          if (stub) {
            try {
              writeFileSync(dest, stub, { mode: 0o755 })
            } catch {
              // Do nothing
            }
          }
          throw copyErr
        }
      }
    } else if (err.code === 'EXDEV' || err.code === 'EPERM') {
      // Cross-device or no-link-perms — copyFileSync overwrites existing dest.
      copyFileSync(src, dest)
    } else {
      throw err
    }
  }
  if (process.platform !== 'win32') {
    chmodSync(dest, 0o755)
  }
}

// npm shows a dependency's postinstall output only when it exits non-zero.
function failInstall() {
  console.error(
    '  Failing this install so npm does not leave a non-working claude in place.',
  )
  process.exitCode = 1
}

// FAIL_ON_MISSING_NATIVE builds fail the install when the platform package is
// missing or not shipped for this platform. A user who passed --omit=optional
// (or has omit=optional in npmrc) asked for that outcome, so theirs stays soft;
// npm hands that setting to lifecycle scripts as npm_config_omit (the
// deprecated optional=false / --no-optional spelling is never exported).
function failInstallUnlessOptionalOmitted() {
  if (
    !FAIL_ON_MISSING_NATIVE ||
    (process.env.npm_config_omit || '').includes('optional')
  ) {
    return
  }
  failInstall()
}

function main() {
  const platformKey = getPlatformKey()
  const info = PLATFORMS[platformKey]

  if (!info) {
    console.error(
      `[${WRAPPER_NAME} postinstall] Unsupported platform: ${process.platform} ${arch()}`,
    )
    console.error(`  Supported: ${Object.keys(PLATFORMS).join(', ')}`)
    if (process.platform === 'freebsd') {
      console.error(
        '  FreeBSD is not natively supported on this version of Claude Code. Consider running under Linuxulator.',
      )
    }
    return
  }

  const optionalDeps = require('./package.json').optionalDependencies || {}
  if (!optionalDeps[info.pkg]) {
    console.error(
      `[${WRAPPER_NAME} postinstall] Native binaries for ${platformKey} are not available on this release channel.`,
    )
    console.error(
      `  Available: ${Object.keys(optionalDeps)
        .map(p => p.replace(PACKAGE_PREFIX + '-', ''))
        .join(', ')}`,
    )
    failInstallUnlessOptionalOmitted()
    return
  }

  let src
  try {
    const pkgDir = resolvePlatformPackageDir(info.pkg, optionalDeps[info.pkg])
    src = path.join(pkgDir, info.bin)
  } catch (err) {
    if (err?.code === 'EDUPLICATEPKG') {
      console.error(
        `[${WRAPPER_NAME} postinstall] Two copies of the native package "${info.pkg}" are installed where one is expected, so neither was used:`,
      )
      console.error(`    ${err.found[0]}`)
      console.error(`    ${err.found[1]}`)
      console.error(
        `  Global install: npm rm -g ${WRAPPER_NAME} ${info.pkg}, then npm i -g ${WRAPPER_NAME}. Otherwise delete both directories and reinstall ${WRAPPER_NAME}.`,
      )
      failInstall()
      return
    }
    if (err?.code === 'EUNREADABLEPKG') {
      console.error(
        `[${WRAPPER_NAME} postinstall] The native package at ${err.dir} was rejected: its package.json cannot be used (${err.reason}).`,
      )
      console.error(
        `  Check ${path.join(err.dir, 'package.json')}; if it is damaged or unreadable, delete ${err.dir} and reinstall ${WRAPPER_NAME}.`,
      )
      failInstall()
      return
    }
    console.error(
      `[${WRAPPER_NAME} postinstall] Native package "${info.pkg}" not found.`,
    )
    if (platformKey === 'darwin-arm64' && arch() === 'x64') {
      console.error(
        '  You are running x64 Node under Rosetta 2 on Apple Silicon. npm only',
      )
      console.error(
        '  installed the darwin-x64 binary, which requires AVX (not emulated by',
      )
      console.error(
        '  Rosetta). Install arm64 Node and reinstall — e.g. via nvm:',
      )
      console.error(
        '    arch -arm64 zsh -c "nvm install --lts && npm i -g ' +
          WRAPPER_NAME +
          '"',
      )
      return
    }
    console.error(
      '  This happens with --omit=optional or when the download failed; re-run the install to fetch it.',
    )
    console.error(
      '  The `claude` command will print instructions when invoked.',
    )
    console.error('  Fallback: node ' + path.join(__dirname, 'cli-wrapper.cjs'))
    failInstallUnlessOptionalOmitted()
    return
  }

  // Always write to bin/claude.exe — the package.json bin field points here.
  // The .exe extension + no-shebang stub makes npm's cmd-shim (generated at
  // install time, before postinstall) emit a direct exec on Windows; Unix
  // ignores the extension. Same pattern as Bun's npm package.
  const dest = path.join(__dirname, 'bin', 'claude.exe')

  try {
    placeBinary(src, dest)
  } catch (err) {
    console.error(
      `[${WRAPPER_NAME} postinstall] Failed to place binary: ${err.message}`,
    )
    console.error('  Fallback: node ' + path.join(__dirname, 'cli-wrapper.cjs'))
    process.exitCode = 1
  }
}

main()
