import os

def fix_indentation(file_path, use_tabs=True):
    with open(file_path, 'r') as file:
        content = file.read()
    
    lines = content.split('\n')
    fixed_lines = []
    
    for line in lines:
        # Count leading whitespace
        leading_space = len(line) - len(line.lstrip())
        if leading_space > 0:
            indent_level = leading_space // 4  # assuming 4 spaces per level
            if use_tabs:
                new_indent = '\t' * indent_level
            else:
                new_indent = ' ' * (indent_level * 4)
            fixed_lines.append(new_indent + line.lstrip())
        else:
            fixed_lines.append(line)
    
    with open(file_path, 'w') as file:
        file.write('\n'.join(fixed_lines))

# Process all GDScript files in the project
project_path = '~/CastleFight/'  # Replace with your project path
use_tabs = True  # Set to False if you want to use spaces instead

for root, dirs, files in os.walk(project_path):
    for file in files:
        if file.endswith('.gd'):
            file_path = os.path.join(root, file)
            print(f"Fixing: {file_path}")
            try:
                fix_indentation(file_path, use_tabs=use_tabs)
                print(f"✓ Successfully fixed {file_path}")
            except Exception as e:
                print(f"✗ Error fixing {file_path}: {str(e)}")
