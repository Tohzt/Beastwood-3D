# Removing Large Files from Git History

Your branch has large files in its commit history that exceed GitHub's limits. Here's how to fix it:

## Option 1: BFG Repo-Cleaner (Recommended for Windows)

1. **Download BFG**: 
   - Go to https://rtyley.github.io/bfg-repo-cleaner/
   - Download `bfg-1.14.0.jar` (or latest version)

2. **Run BFG** (in PowerShell, from your project root):
   ```powershell
   # Clone a fresh copy (BFG needs this)
   cd ..
   git clone --mirror https://github.com/Tohzt/Beastwood-3D.git Beastwood-3D-mirror.git
   cd Beastwood-3D-mirror.git
   
   # Remove large files (adjust path to where you saved bfg.jar)
   java -jar C:\path\to\bfg-1.14.0.jar --delete-folders Exports
   java -jar C:\path\to\bfg-1.14.0.jar --delete-files "Nug_Image_0.png"
   
   # Clean up
   git reflog expire --expire=now --all
   git gc --prune=now --aggressive
   
   # Push the cleaned history
   git push
   ```

## Option 2: git-filter-repo (Modern Tool)

1. **Install git-filter-repo**:
   ```powershell
   pip install git-filter-repo
   ```

2. **Run it**:
   ```powershell
   cd c:\Users\Steve\Projects\Godot\Beastwood
   git filter-repo --path Exports --invert-paths
   git filter-repo --path Assets/Objects/Nug/Nug_Image_0.png --invert-paths
   git push -f origin droplet_server
   ```

## Option 3: Fresh Branch (If branch is new/unshared)

If this branch hasn't been shared with others, you can create a fresh branch:

```powershell
# Create a new branch from main (or wherever your branch started)
git checkout main
git checkout -b droplet_server-clean

# Cherry-pick commits you want (skip ones with large files)
# Or manually recreate your changes

# Then delete old branch and rename
git branch -D droplet_server
git branch -m droplet_server-clean droplet_server
git push -f origin droplet_server
```

## Current Status

✅ Large files removed from current commit
✅ `.gitignore` updated to prevent future tracking
⚠️ Files still exist in branch history (needs one of the options above)

## After Cleaning History

Once you've cleaned the history using one of the methods above:
```powershell
git push -f origin droplet_server
```

**Note**: Force pushing rewrites history. Only do this if:
- This is your feature branch
- No one else is working on this branch
- You've backed up your work
