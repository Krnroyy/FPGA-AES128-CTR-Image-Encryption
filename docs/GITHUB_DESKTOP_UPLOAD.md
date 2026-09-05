# Upload with GitHub Desktop

These steps update the existing repository without deleting its commit history.

## 1. Clone the existing repository

1. Open GitHub Desktop.
2. Select **File → Clone repository**.
3. Open the **URL** tab.
4. Enter `https://github.com/Krnroyy/FPGA-AES128-CTR-Image-Encryption`.
5. Choose a short local path such as `C:\GitHub\FPGA-AES128-CTR-Image-Encryption`.
6. Select **Clone**.

Do not choose **Create new repository** because the repository already exists online.

## 2. Create a safe update branch

1. Select **Current Branch** at the top.
2. Select **New Branch**.
3. Name it `zcu104-project-upgrade`.
4. Create the branch from the current default branch.

This keeps the earlier project recoverable while the new files are checked.

## 3. Preserve the earlier README

Before copying the upgrade package, open the cloned repository in File Explorer. If its current `README.md` contains useful Artix-7 information, create the `docs` folder and rename that file to:

```text
docs/ARTIX7_BASELINE.md
```

## 4. Copy the upgrade files

Extract the supplied GitHub-ready ZIP. Copy everything inside its `github_upload_ready` folder into the cloned repository root.

The cloned folder should then contain the new `README.md`, `.gitignore`, `hardware`, `software`, `host`, `tools`, `docs`, and `results` items alongside any earlier source directories.

Do not copy generated Vivado or Vitis folders such as `.runs`, `.cache`, `.gen`, `vivado_project`, `build`, or an entire Vitis workspace. Do not upload `.bit`, `.xsa`, `.elf`, `.dcp`, `.wdb`, journal, or log files in the main source commit.

## 5. Review the change list

Return to GitHub Desktop and inspect the **Changes** tab.

Expected source changes include:

- Seven Verilog files under `hardware/rtl`
- One Tcl build script
- Vitis source files
- Python host and image-preparation scripts
- Documentation, figures, and reports

If generated files appear, stop and verify that `.gitignore` is in the repository root.

## 6. Commit and push

Use this commit summary:

```text
Add verified ZCU104 AES-128 CTR image pipeline
```

Optional description:

```text
Integrate AXI4-Lite AES accelerator, Cortex-A53 application, UART host receiver, implementation reports, security analysis, and reproducible Vivado build files.
```

Select **Commit to zcu104-project-upgrade**, then select **Publish branch** or **Push origin**.

## 7. Merge into the main branch

After checking the repository on GitHub:

1. Select **Preview Pull Request** in GitHub Desktop.
2. Create a pull request from `zcu104-project-upgrade` into the default branch.
3. Verify that the README images render correctly.
4. Merge the pull request.

Alternatively, if only you use the repository, GitHub Desktop can merge the branch locally through **Branch → Merge into current branch**, followed by **Push origin**.

## 8. Repository settings

On GitHub, add these topics:

```text
fpga  verilog  aes-128  aes-ctr  zcu104  zynq-ultrascale  vivado  vitis  image-encryption  axi4-lite
```

Suggested repository description:

```text
Hardware-accelerated AES-128 CTR image encryption on ZCU104 using Verilog, AXI4-Lite, Cortex-A53, Vitis, and UART verification.
```

Choose a software license only after deciding how others may reuse the code. No license means the code is publicly visible but does not automatically grant reuse rights.

