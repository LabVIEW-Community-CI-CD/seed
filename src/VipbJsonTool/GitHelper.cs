using System;
using System.Diagnostics;
using System.IO;
using System.Linq;

namespace VipbJsonTool
{
    public static class GitHelper
    {
        private static int Run(string cmd, string args, bool throwOnError = true)
        {
            var psi = new ProcessStartInfo(cmd, args)
            {
                RedirectStandardError = true,
                RedirectStandardOutput = true,
                UseShellExecute = false
            };
            var p = Process.Start(psi);
            p.WaitForExit();
            if (p.ExitCode != 0 && throwOnError)
            {
                throw new Exception($"{cmd} {args}\n{p.StandardError.ReadToEnd()}");
            }
            return p.ExitCode;
        }

        public static void CommitAndPush(string branch, string[] files, bool autoPr)
        {
            var token = Environment.GetEnvironmentVariable("GITHUB_TOKEN");
            var repo  = Environment.GetEnvironmentVariable("GITHUB_REPOSITORY");
            if (string.IsNullOrEmpty(token) || string.IsNullOrEmpty(repo))
            {
                Console.Error.WriteLine("Missing GITHUB_TOKEN or GITHUB_REPOSITORY; skip push.");
                return;
            }

            Run("git", "config user.name "GitHub Actions"");
            Run("git", "config user.email "github-actions[bot]@users.noreply.github.com"");
            Run("git", $"checkout -B {branch}");
            foreach (var f in files.Where(File.Exists))
            {
                Run("git", $"add {f}");
            }

            // commit only if there are staged changes
            if (Run("git", "diff --cached --quiet", false) != 0)
            {
                Run("git", "commit -m "Automated update via JSON-VIPB Action v1.3.0"");
            }
            else
            {
                Console.WriteLine("No changes to commit.");
                return; // nothing to push
            }

            Run("git", $"remote set-url origin https://x-access-token:{token}@github.com/{repo}.git");
            Run("git", $"push origin {branch} --force");

            if (autoPr)
            {
                // check if PR exists
                var check = $"https://api.github.com/repos/{repo}/pulls?head={Uri.EscapeDataString(repo.Split('/')[0]+":"+branch)}&state=open";
                Run("curl", $"-s -H "Authorization: token {token}" "{check}" -o pr.json", false);
                var json = File.ReadAllText("pr.json");
                if (json.Trim() == "[]" )
                {
                    var body = $"{{\"title\":\"Automated VIPB update\",\"head\":\"{branch}\",\"base\":\"main\"}}";
                    Run("curl", $"-X POST -H "Authorization: token {token}" -H "User-Agent: json-vipb-action" -H "Content-Type: application/json" -d "{body}" https://api.github.com/repos/{repo}/pulls");
                }
                else
                {
                    Console.WriteLine("PR already exists; skipped creating new one.");
                }
            }
        }
    }
}
