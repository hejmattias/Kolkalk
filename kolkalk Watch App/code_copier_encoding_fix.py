
import os
import pyperclip

def read_files_in_directory(directory_path):
    all_code = ""
    for root, dirs, files in os.walk(directory_path):
        for file_name in files:
            # Skip the script itself to avoid copying its content
            if file_name == os.path.basename(__file__):
                continue
            file_path = os.path.join(root, file_name)
            try:
                # Open the file and ignore any encoding errors
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as file:
                    all_code += f"--- Content of {file_path} ---\n"
                    all_code += file.read() + "\n\n"
            except FileNotFoundError:
                all_code += f"--- File not found: {file_path} ---\n\n"
    return all_code

def copy_to_clipboard(text):
    pyperclip.copy(text)
    print("Code copied to clipboard!")

if __name__ == "__main__":
    # Get the directory path where the script is located
    script_directory = os.path.dirname(os.path.abspath(__file__))
    
    # Read the files in the same directory as the script and copy the code to the clipboard
    code = read_files_in_directory(script_directory)
    copy_to_clipboard(code)
