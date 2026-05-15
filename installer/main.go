// Command installer sets up Zed and links this repo's config idempotently.
//
// Idempotent by design: an existing Zed install is detected and skipped,
// config files already symlinked to this repo are left untouched, and any
// real (non-symlink) config file is backed up before being replaced.
//
//	go run ./installer            # detect platform, install if missing, link config
//	go run ./installer -dry-run   # print actions, change nothing
//	go run ./installer -link-only # only (re)link config, never install
//	go run ./installer -no-install# link config, skip Zed install step
package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

var (
	dryRun   = flag.Bool("dry-run", false, "print actions without changing anything")
	linkOnly = flag.Bool("link-only", false, "only link config, do not install Zed")
	noInst   = flag.Bool("no-install", false, "skip the Zed install step")
)

func main() {
	flag.Parse()
	log("platform: %s/%s", runtime.GOOS, runtime.GOARCH)

	repoCfg, err := repoConfigDir()
	if err != nil {
		die("locate repo config: %v", err)
	}

	if !*linkOnly && !*noInst {
		if err := ensureZed(); err != nil {
			die("install Zed: %v", err)
		}
	} else {
		log("skip install (flag set)")
	}

	if err := linkConfig(repoCfg); err != nil {
		die("link config: %v", err)
	}
	log("done.")
}

// repoConfigDir returns <repo>/config, resolved relative to this source tree
// so the installer works regardless of the caller's working directory.
func repoConfigDir() (string, error) {
	exe, err := os.Getwd()
	if err != nil {
		return "", err
	}
	// Walk up until we find a dir containing config/keymap.json.
	for dir := exe; ; {
		cand := filepath.Join(dir, "config", "keymap.json")
		if _, err := os.Stat(cand); err == nil {
			return filepath.Join(dir, "config"), nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", fmt.Errorf("config/ not found above %s", exe)
		}
		dir = parent
	}
}

// ---------------------------------------------------------------------------
// Zed install (idempotent: present => skip)
// ---------------------------------------------------------------------------

func ensureZed() error {
	if bin := zedBinary(); bin != "" {
		log("Zed already installed (%s) — skip", bin)
		return nil
	}
	log("Zed not found — installing")

	switch runtime.GOOS {
	case "linux", "darwin":
		pm := detectPkgMgr()
		log("package manager: %s", pm.name)
		return pm.install()
	case "windows":
		return installWindows()
	default:
		return fmt.Errorf("unsupported OS %q", runtime.GOOS)
	}
}

// zedBinary returns the path to an installed Zed CLI, or "" if absent.
// Arch packages it as `zeditor`; upstream installs ship `zed`.
func zedBinary() string {
	names := []string{"zed", "zeditor"}
	if runtime.GOOS == "windows" {
		names = []string{"zed.exe", "zed"}
	}
	for _, n := range names {
		if p, err := exec.LookPath(n); err == nil {
			return p
		}
	}
	return ""
}

type pkgMgr struct {
	name    string
	install func() error
}

// detectPkgMgr picks a manager from /etc/os-release (ID, then ID_LIKE),
// falling back to whichever manager binary is on PATH. macOS => brew.
func detectPkgMgr() pkgMgr {
	if runtime.GOOS == "darwin" {
		return pkgMgr{"brew", func() error {
			ensureBrew()
			return run("brew", "install", "--cask", "zed")
		}}
	}

	ids := osReleaseIDs()
	byID := map[string]pkgMgr{
		"arch":     {"pacman", func() error { return run("sudo", "pacman", "-S", "--needed", "--noconfirm", "zed") }},
		"debian":   {"apt", aptInstall},
		"ubuntu":   {"apt", aptInstall},
		"fedora":   {"dnf", func() error { return run("sudo", "dnf", "install", "-y", "zed") }},
		"opensuse": {"zypper", func() error { return run("sudo", "zypper", "--non-interactive", "install", "zed") }},
		"alpine":   {"apk", func() error { return run("sudo", "apk", "add", "zed") }},
	}
	for _, id := range ids {
		if pm, ok := byID[id]; ok {
			return pm
		}
	}
	// Fallback: probe PATH.
	for bin, pm := range map[string]pkgMgr{
		"pacman": byID["arch"], "apt": byID["debian"],
		"dnf": byID["fedora"], "zypper": byID["opensuse"], "apk": byID["alpine"],
	} {
		if _, err := exec.LookPath(bin); err == nil {
			return pm
		}
	}
	// Last resort: upstream distro-agnostic script.
	return pkgMgr{"zed.dev/install.sh", func() error {
		return runShell("curl -fsSL https://zed.dev/install.sh | sh")
	}}
}

func aptInstall() error {
	if err := run("sudo", "apt-get", "update"); err != nil {
		return err
	}
	return run("sudo", "apt-get", "install", "-y", "zed")
}

func installWindows() error {
	for _, c := range [][]string{
		{"winget", "install", "-e", "--id", "Zed.Zed", "--accept-source-agreements", "--accept-package-agreements"},
		{"scoop", "install", "zed"},
		{"choco", "install", "zed", "-y"},
	} {
		if _, err := exec.LookPath(c[0]); err == nil {
			return run(c[0], c[1:]...)
		}
	}
	return fmt.Errorf("no winget/scoop/choco found; install Zed manually from https://zed.dev")
}

func ensureBrew() {
	if _, err := exec.LookPath("brew"); err != nil {
		log("WARNING: Homebrew not found — install from https://brew.sh then re-run")
	}
}

func osReleaseIDs() []string {
	f, err := os.Open("/etc/os-release")
	if err != nil {
		return nil
	}
	defer f.Close()
	var ids []string
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		for _, key := range []string{"ID=", "ID_LIKE="} {
			if strings.HasPrefix(line, key) {
				v := strings.Trim(strings.TrimPrefix(line, key), `"`)
				ids = append(ids, strings.Fields(v)...)
			}
		}
	}
	return ids
}

// ---------------------------------------------------------------------------
// Config linking (idempotent: correct symlink => skip; real file => backup)
// ---------------------------------------------------------------------------

func linkConfig(repoCfg string) error {
	dst, err := zedConfigDir()
	if err != nil {
		return err
	}
	if err := mkdirAll(dst); err != nil {
		return err
	}
	for _, name := range []string{"settings.json", "keymap.json"} {
		src := filepath.Join(repoCfg, name)
		tgt := filepath.Join(dst, name)
		if err := linkOne(src, tgt); err != nil {
			return fmt.Errorf("%s: %w", name, err)
		}
	}
	return nil
}

func linkOne(src, tgt string) error {
	if cur, err := os.Readlink(tgt); err == nil {
		if cur == src {
			log("%s already linked — skip", tgt)
			return nil
		}
		log("relinking %s (was -> %s)", tgt, cur)
		if !*dryRun {
			if err := os.Remove(tgt); err != nil {
				return err
			}
		}
	} else if _, err := os.Lstat(tgt); err == nil {
		bak := fmt.Sprintf("%s.bak-%s", tgt, time.Now().Format("20060102-150405"))
		log("backup existing %s -> %s", tgt, bak)
		if !*dryRun {
			if err := os.Rename(tgt, bak); err != nil {
				return err
			}
		}
	}
	log("symlink %s -> %s", tgt, src)
	if *dryRun {
		return nil
	}
	return os.Symlink(src, tgt)
}

// zedConfigDir returns Zed's user config directory for the current OS.
func zedConfigDir() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	switch runtime.GOOS {
	case "windows":
		if ad := os.Getenv("APPDATA"); ad != "" {
			return filepath.Join(ad, "Zed"), nil
		}
		return filepath.Join(home, "AppData", "Roaming", "Zed"), nil
	default: // linux, darwin
		if x := os.Getenv("XDG_CONFIG_HOME"); x != "" {
			return filepath.Join(x, "zed"), nil
		}
		return filepath.Join(home, ".config", "zed"), nil
	}
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

func mkdirAll(p string) error {
	log("ensure dir %s", p)
	if *dryRun {
		return nil
	}
	return os.MkdirAll(p, 0o755)
}

func run(name string, args ...string) error {
	log("$ %s %s", name, strings.Join(args, " "))
	if *dryRun {
		return nil
	}
	c := exec.Command(name, args...)
	c.Stdout, c.Stderr, c.Stdin = os.Stdout, os.Stderr, os.Stdin
	return c.Run()
}

func runShell(cmd string) error {
	log("$ %s", cmd)
	if *dryRun {
		return nil
	}
	c := exec.Command("sh", "-c", cmd)
	c.Stdout, c.Stderr, c.Stdin = os.Stdout, os.Stderr, os.Stdin
	return c.Run()
}

func log(f string, a ...any) { fmt.Printf("[zed-config] "+f+"\n", a...) }
func die(f string, a ...any) { fmt.Fprintf(os.Stderr, "[zed-config] FATAL: "+f+"\n", a...); os.Exit(1) }
