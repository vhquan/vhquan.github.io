const fs = require('fs');
const path = require('path');

let html = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/style.css">
    <title>Notes</title>
</head>
<body>
<h1>/home/vhquan/</h1>
<ul class="post-list">
`

const getFileList = (dir, ext) => {
    let files = [];
    const items = fs.readdirSync(dir, { withFileTypes: true });

    for (const item of items) {
        if (item.isDirectory()) {
            files = [...files, ...getFileList(`${dir}/${item.name}`)];
        } else {
            if (path.extname(item.name) === ext)
                files.push(`${dir}/${item.name}`);
        }
    }

    return files;
}

const files = getFileList('./posts', '.txt');

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
