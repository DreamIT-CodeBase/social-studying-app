import os

target_file = r"c:\Users\tarun\Downloads\Social-study-app\social-studying-app\flutter_app\lib\features\documents\presentation\documents_list_screen.dart"

code_to_append = """
enum _UploadSource { camera, gallery, file }

class _UploadSourceSheet extends StatelessWidget {
  const _UploadSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Text(
              'Upload Document',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded),
            title: const Text('Take Photo'),
            onTap: () => Navigator.of(context).pop(_UploadSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.of(context).pop(_UploadSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.folder_rounded),
            title: const Text('Choose File'),
            onTap: () => Navigator.of(context).pop(_UploadSource.file),
          ),
        ],
      ),
    );
  }
}
"""

with open(target_file, "a", encoding="utf-8") as f:
    f.write("\n" + code_to_append)
