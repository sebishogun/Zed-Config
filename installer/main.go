// Command installer sets up editor configs from this repo idempotently,
// across machines and OSes.
//
// Targets: zed, jetbrains, vscode, nvim. With no -only flags, all run.
//
//	go run ./installer                 # all targets
//	go run ./installer -only zed,nvim  # subset
//	go run ./installer -dry-run        # print actions, change nothing
//	go run ./installer -no-install     # link only, never install editors
//
// Idempotent: a config already symlinked to this repo is left alone; a
// real (non-symlink) file/dir is moved to <name>.bak-<timestamp> before
// the symlink is created. Nothing is overwritten.
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
	dryRun = flag.Bool("dry-run", false, "print actions without changing anything")
	noInst = flag.Bool("no-install", false, "skip editor install steps, only link configs")
	only   = flag.String("only", "", "comma-separated subset: zed,jetbrains,vscode,nvim (default: all)")
)

func main() {
	flag.Parse()
	log("platform: %s/%s", runtime.GOOS, runtime.GOARCH)

	root, err := repoRoot()
	if err != nil {
		die("locate repo root: %v", err)
	}
	log("repo: %s", root)

	targets := map[string]bool{"zed": true, "jetbrains": true, "vscode": true, "nvim": true}
	if *only != "" {
		for k := range targets {
			targets[k] = false
		}
		for t := range strings.SplitSeq(*only, ",") {
			t = strings.TrimSpace(t)
			if _, ok := targets[t]; !ok {
				die("unknown target %q (valid: zed jetbrains vscode nvim)", t)
			}
			targets[t] = true
		}
	}

	steps := []struct {
		name string
		fn   func(string) error
	}{
		{"zed", setupZed},
		{"jetbrains", setupJetBrains},
		{"vscode", setupVSCode},
		{"nvim", setupNvim},
	}
	for _, s := range steps {
		if !targets[s.name] {
			continue
		}
		log("== %s ==", s.name)
		if err := s.fn(root); err != nil {
			die("%s: %v", s.name, err)
		}
	}
	log("done.")
}

// ---------------------------------------------------------------------------
// targets
// ---------------------------------------------------------------------------

func setupZed(root string) error {
	if !*noInst && zedBinary() == "" {
		log("Zed not found — installing")
		if err := installPkg("zed", "Zed.Zed", "--cask"); err != nil {
			return err
		}
	} else {
		log("Zed present or install skipped")
	}
	dst, err := zedConfigDir()
	if err != nil {
		return err
	}
	if err := mkdirAll(dst); err != nil {
		return err
	}
	for _, n := range []string{"settings.json", "keymap.json"} {
		if err := linkOne(filepath.Join(root, "zed", "config", n), filepath.Join(dst, n)); err != nil {
			return err
		}
	}
	return nil
}

// JetBrains: ~/.ideavimrc (IdeaVim, the editor/leader layer) is read by
// EVERY JetBrains IDE. The IDE-level keymap "LazyVim Style" is linked
// into each product's keymaps/ and activated via options/keymap.xml.
// IDEs are not auto-installed.
func setupJetBrains(root string) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	if err := linkOne(filepath.Join(root, "jetbrains", ".ideavimrc"),
		filepath.Join(home, ".ideavimrc")); err != nil {
		return err
	}

	srcKeymap := filepath.Join(root, "jetbrains", "keymaps", "LazyVim.xml")
	dirs, _ := filepath.Glob(filepath.Join(home, ".config", "JetBrains", "*"))
	if len(dirs) == 0 {
		log("no JetBrains IDE config dir yet — ~/.ideavimrc linked; keymap installs when an IDE appears")
		return nil
	}
	for _, d := range dirs {
		if base := filepath.Base(d); strings.HasPrefix(base, ".") || base == "consentOptions" {
			continue
		}
		km := filepath.Join(d, "keymaps")
		if err := mkdirAll(km); err != nil {
			return err
		}
		if err := linkOne(srcKeymap, filepath.Join(km, "LazyVim.xml")); err != nil {
			return err
		}
		if err := activateKeymap(d); err != nil {
			return err
		}
		log("JetBrains: %s configured", filepath.Base(d))
	}
	return nil
}

// activateKeymap writes <product>/options/keymap.xml selecting the
// "LazyVim Style" keymap, unless it is already active. Standard
// KeymapManager component schema.
func activateKeymap(productDir string) error {
	opts := filepath.Join(productDir, "options")
	kf := filepath.Join(opts, "keymap.xml")
	const want = `name="LazyVim Style"`
	if b, err := os.ReadFile(kf); err == nil && strings.Contains(string(b), want) {
		log("%s: keymap already active — skip", kf)
		return nil
	}
	body := `<application>
  <component name="KeymapManager">
    <active_keymap name="LazyVim Style" />
  </component>
</application>
`
	log("activate LazyVim Style -> %s", kf)
	if *dryRun {
		return nil
	}
	if err := os.MkdirAll(opts, 0o755); err != nil {
		return err
	}
	if _, err := os.Stat(kf); err == nil {
		bak := fmt.Sprintf("%s.bak-%s", kf, time.Now().Format("20060102-150405"))
		if err := os.Rename(kf, bak); err != nil {
			return err
		}
		log("backup %s -> %s", kf, bak)
	}
	return os.WriteFile(kf, []byte(body), 0o644)
}

// VSCode family: link into every fork that is actually installed.
func setupVSCode(root string) error {
	base, err := vscodeUserBase()
	if err != nil {
		return err
	}
	forks := []string{"Code", "Code - OSS", "VSCodium", "Cursor", "Windsurf", "Antigravity"}
	linked := 0
	for _, f := range forks {
		userDir := filepath.Join(base, f, "User")
		if _, err := os.Stat(userDir); err != nil {
			continue // fork not installed
		}
		for _, n := range []string{"settings.json", "keybindings.json"} {
			if err := linkOne(filepath.Join(root, "vscode", n), filepath.Join(userDir, n)); err != nil {
				return fmt.Errorf("%s/%s: %w", f, n, err)
			}
		}
		linked++
		log("linked %s", f)
	}
	if linked == 0 {
		log("no VSCode-family editor installed — nothing linked")
	}
	return nil
}

func setupNvim(root string) error {
	if !*noInst {
		if _, err := exec.LookPath("nvim"); err != nil {
			log("nvim not found — installing")
			if err := installPkg("neovim", "Neovim.Neovim", ""); err != nil {
				return err
			}
		} else {
			log("nvim present")
		}
		if err := ensureNvimDeps(); err != nil {
			return err
		}
	}
	dst, err := nvimConfigDir()
	if err != nil {
		return err
	}
	if err := mkdirAll(filepath.Dir(dst)); err != nil {
		return err
	}
	return linkOne(filepath.Join(root, "nvim"), dst)
}

// ensureNvimDeps installs LazyVim's external toolchain — only the tools
// missing from PATH. node/npm are intentionally NOT installed: this
// machine provides them via mise; a distro package would conflict.
// pkg names differ per manager; "" means no package on that manager
// (skipped with a warning).
func ensureNvimDeps() error {
	type dep struct {
		bin                                 string
		pac, apt, dnf, zyp, apk, brew, wing string
	}
	deps := []dep{
		{"git", "git", "git", "git", "git", "git", "git", "Git.Git"},
		{"make", "make", "make", "make", "make", "make", "make", "GnuWin32.Make"},
		{"gcc", "gcc", "gcc", "gcc", "gcc", "gcc", "gcc", ""},
		{"unzip", "unzip", "unzip", "unzip", "unzip", "unzip", "unzip", ""},
		{"curl", "curl", "curl", "curl", "curl", "curl", "curl", "cURL.cURL"},
		{"rg", "ripgrep", "ripgrep", "ripgrep", "ripgrep", "ripgrep", "ripgrep", "BurntSushi.ripgrep.MSVC"},
		{"fd", "fd", "fd-find", "fd-find", "fd", "fd", "fd", "sharkdp.fd"},
		{"lazygit", "lazygit", "", "lazygit", "lazygit", "lazygit", "lazygit", "JesseDuffield.lazygit"},
		{"wl-copy", "wl-clipboard", "wl-clipboard", "wl-clipboard", "wl-clipboard", "wl-clipboard", "", ""},
		{"tree-sitter", "tree-sitter-cli", "", "", "", "", "tree-sitter", ""},
	}

	mgr := ""
	switch runtime.GOOS {
	case "darwin":
		mgr = "brew"
	case "windows":
		mgr = "winget"
	default:
		mgr = linuxMgr()
	}
	pick := func(d dep) string {
		switch mgr {
		case "pacman":
			return d.pac
		case "apt":
			return d.apt
		case "dnf":
			return d.dnf
		case "zypper":
			return d.zyp
		case "apk":
			return d.apk
		case "brew":
			return d.brew
		case "winget":
			return d.wing
		}
		return ""
	}

	var missing []dep
	for _, d := range deps {
		if _, err := exec.LookPath(d.bin); err != nil {
			missing = append(missing, d)
		}
	}
	if len(missing) == 0 {
		log("nvim deps: all present — skip")
		return nil
	}
	for _, d := range missing {
		pkg := pick(d)
		if pkg == "" {
			log("nvim deps: %s missing, no %s package — install manually", d.bin, mgr)
			continue
		}
		log("nvim deps: installing %s (%s)", d.bin, pkg)
		if err := installPkg(pkg, d.wing, ""); err != nil {
			log("nvim deps: WARNING failed to install %s: %v", pkg, err)
		}
	}
	log("nvim deps: node/npm left to mise (not installed)")
	return nil
}

// ---------------------------------------------------------------------------
// install helpers
// ---------------------------------------------------------------------------

func zedBinary() string {
	for _, n := range []string{"zed", "zeditor", "zed.exe"} {
		if p, err := exec.LookPath(n); err == nil {
			return p
		}
	}
	return ""
}

// installPkg installs pkg via the detected manager. brewExtra (e.g.
// "--cask") and wingetID let the same call cover macOS/Windows.
func installPkg(pkg, wingetID, brewExtra string) error {
	switch runtime.GOOS {
	case "darwin":
		if _, err := exec.LookPath("brew"); err != nil {
			log("WARNING: Homebrew missing — install from https://brew.sh")
			return nil
		}
		args := []string{"install"}
		if brewExtra != "" {
			args = append(args, brewExtra)
		}
		return run("brew", append(args, pkg)...)
	case "windows":
		if _, err := exec.LookPath("winget"); err == nil {
			return run("winget", "install", "-e", "--id", wingetID,
				"--accept-source-agreements", "--accept-package-agreements")
		}
		return fmt.Errorf("winget not found; install %s manually", pkg)
	default: // linux
		switch linuxMgr() {
		case "pacman":
			return run("sudo", "pacman", "-S", "--needed", "--noconfirm", pkg)
		case "apt":
			if err := run("sudo", "apt-get", "update"); err != nil {
				return err
			}
			return run("sudo", "apt-get", "install", "-y", pkg)
		case "dnf":
			return run("sudo", "dnf", "install", "-y", pkg)
		case "zypper":
			return run("sudo", "zypper", "--non-interactive", "install", pkg)
		case "apk":
			return run("sudo", "apk", "add", pkg)
		default:
			return fmt.Errorf("no supported package manager found for %s", pkg)
		}
	}
}

// linuxMgr picks from /etc/os-release ID/ID_LIKE, else probes PATH.
func linuxMgr() string {
	byID := map[string]string{
		"arch": "pacman", "manjaro": "pacman", "endeavouros": "pacman",
		"debian": "apt", "ubuntu": "apt", "linuxmint": "apt", "pop": "apt",
		"fedora": "dnf", "rhel": "dnf", "centos": "dnf",
		"opensuse": "zypper", "opensuse-tumbleweed": "zypper", "sles": "zypper",
		"alpine": "apk",
	}
	for _, id := range osReleaseIDs() {
		if m, ok := byID[id]; ok {
			return m
		}
	}
	for _, m := range []string{"pacman", "apt", "dnf", "zypper", "apk"} {
		if _, err := exec.LookPath(m); err == nil {
			return m
		}
	}
	return ""
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
		for _, k := range []string{"ID=", "ID_LIKE="} {
			if rest, ok := strings.CutPrefix(line, k); ok {
				ids = append(ids, strings.Fields(strings.Trim(rest, `"`))...)
			}
		}
	}
	return ids
}

// ---------------------------------------------------------------------------
// path resolution
// ---------------------------------------------------------------------------

func repoRoot() (string, error) {
	wd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	for dir := wd; ; {
		if _, err := os.Stat(filepath.Join(dir, "go.mod")); err == nil {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", fmt.Errorf("go.mod not found above %s", wd)
		}
		dir = parent
	}
}

func xdgConfig() (string, error) {
	if x := os.Getenv("XDG_CONFIG_HOME"); x != "" {
		return x, nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".config"), nil
}

func zedConfigDir() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	switch runtime.GOOS {
	case "windows":
		return filepath.Join(os.Getenv("APPDATA"), "Zed"), nil
	default: // linux, darwin (Zed uses ~/.config/zed on both)
		cfg, err := xdgConfig()
		if err != nil {
			return "", err
		}
		_ = home
		return filepath.Join(cfg, "zed"), nil
	}
}

func nvimConfigDir() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	if runtime.GOOS == "windows" {
		return filepath.Join(os.Getenv("LOCALAPPDATA"), "nvim"), nil
	}
	cfg, err := xdgConfig()
	if err != nil {
		return "", err
	}
	_ = home
	return filepath.Join(cfg, "nvim"), nil
}

func vscodeUserBase() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	switch runtime.GOOS {
	case "windows":
		return os.Getenv("APPDATA"), nil
	case "darwin":
		return filepath.Join(home, "Library", "Application Support"), nil
	default:
		cfg, err := xdgConfig()
		if err != nil {
			return "", err
		}
		return cfg, nil
	}
}

// ---------------------------------------------------------------------------
// idempotent linking
// ---------------------------------------------------------------------------

func linkOne(src, tgt string) error {
	if _, err := os.Stat(src); err != nil {
		return fmt.Errorf("source missing: %s", src)
	}
	if cur, err := os.Readlink(tgt); err == nil {
		if cur == src {
			log("%s already linked — skip", tgt)
			return nil
		}
		log("relink %s (was -> %s)", tgt, cur)
		if !*dryRun {
			if err := os.Remove(tgt); err != nil {
				return err
			}
		}
	} else if _, err := os.Lstat(tgt); err == nil {
		bak := fmt.Sprintf("%s.bak-%s", tgt, time.Now().Format("20060102-150405"))
		log("backup %s -> %s", tgt, bak)
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

func log(f string, a ...any) { fmt.Printf("[dotfiles] "+f+"\n", a...) }
func die(f string, a ...any) {
	fmt.Fprintf(os.Stderr, "[dotfiles] FATAL: "+f+"\n", a...)
	os.Exit(1)
}
