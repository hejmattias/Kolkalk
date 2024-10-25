import os
import pyperclip

def read_files_in_directory(directory_path, allowed_extensions=None):
    if allowed_extensions is None:
        # Standardlista över textfiländelser, inklusive nya tillägg
        allowed_extensions = [
            '.txt', '.md', '.py', '.html', '.htm', '.css', '.js',
            '.json', '.xml', '.csv', '.java', '.c', '.cpp', '.rb',
            '.php', '.sh', '.bat', '.ini', '.cfg', '.log', '.tex',
            '.sql', '.yaml', '.yml', '.swift', '.plist', '.entitlements'
        ]
    
    all_code = ""
    for root, dirs, files in os.walk(directory_path):
        for file_name in files:
            # Hämta filens ändelse
            _, ext = os.path.splitext(file_name)
            ext = ext.lower()
            
            # Kontrollera om filen har en tillåten textändelse
            if ext not in allowed_extensions:
                continue  # Hoppa över filer som inte är textfiler
            
            # Hoppa över skriptet självt för att undvika kopiering av dess innehåll
            if file_name == os.path.basename(__file__):
                continue
            
            file_path = os.path.join(root, file_name)
            try:
                # Öppna filen och ignorera eventuella kodningsfel
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as file:
                    all_code += f"--- Innehåll från {file_path} ---\n"
                    all_code += file.read() + "\n\n"
            except FileNotFoundError:
                all_code += f"--- Fil hittades inte: {file_path} ---\n\n"
    return all_code

def copy_to_clipboard(text):
    pyperclip.copy(text)
    print("Koden har kopierats till urklipp!")

def main():
    while True:
        # Hämta katalogvägen där skriptet är placerat
        script_directory = os.path.dirname(os.path.abspath(__file__))
        
        # Läs in textfiler i samma katalog och undermappar och kopiera koden till urklipp
        code = read_files_in_directory(script_directory)
        copy_to_clipboard(code)
        
        # Fråga användaren om de vill köra skriptet igen
        answer = input("Vill du köra skriptet igen? (j/n): ")
        if answer.lower() != 'j':
            break

if __name__ == "__main__":
    main()
