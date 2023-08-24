const fs = require('fs');
const path = require('path');

let html = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Notes</title>
</head>
<body>
`

const getFileList = (dir) => {
    let files = [];
    const items = fs.readdirSync(dir, { withFileTypes: true });

    for (const item of items) {
        if (item.isDirectory()) {
            files = [...files, ...getFileList(`${dir}/${item.name}`)];
        } else {
            if (path.extname(item.name) === '.txt')
                files.push(`${dir}/${item.name}`);
        }
    }

    return files;
}

const files = getFileList('./build');

for (const file of files) {
    html += `
    <li><a href="${file}">${path.basename(file)}</a></li>
    `;
}

html += `
</ul>
</body>
</html>
`;

// Generate index.html
fs.writeFileSync("index.html", html);