# Lab VM Image

2026.03.31

* Created a new lab-focused VM solution based on the Ubuntu Data Science VM deployment.
* Added a required `labName` parameter to identify each lab (for example, `Ethical Hacking - CS203`).
* Added a new `Capture VM Image` action to deallocate, generalize, and capture the VM to Azure Compute Gallery.
* Added logic to create or reuse image definitions and publish a new image version automatically.
