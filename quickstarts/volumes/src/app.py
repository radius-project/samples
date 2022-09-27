from flask import Flask, request, redirect, url_for
import os

app = Flask(__name__)

@app.route('/')
def index():
    html = """
    <!doctype html>
    <html lang="en">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>Volumes Quickstart</title>
            <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.2.1/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-iYQeCzEYFbKjA/T2uDLTpkwGzCiq6soy8tYaI1GyVh/UjpbCx/TYkiZhlZB6+fzT" crossorigin="anonymous">
        </head>
        <body>
        <div class="container">
            <h1>Volumes Quickstart</h1>
            <p>Here is the contents of /tmpdir:</p>
    """

    if os.path.isdir("/tmpdir"):
        # Check if directory is empty
        if os.listdir("/tmpdir"):
            html += "<ul>"
            for file in os.listdir("/tmpdir"):
                html += f"<li>📄 {file}</li>"
            html += "</ul>"
        else:
            html += """
            <div class="alert alert-primary" role="alert">
                Directory /tmpdir is empty!
            </div>
            """
    else:
        html += """
        <div class="alert alert-danger" role="alert">
            Directory /tmpdir does not exist!
        </div>
        """
    
    html += """
    <h2>Create a file</h2>
    <p>Enter a filename and click the button to create a file in /tmpdir:</p>
    <form class="form-inline" action="/newfile" method="post">
    <div class="form-row">
        <div class="col-md-4">
            <label for="filename" class="sr-only"><b>File name</b></label>
            <input type="text" class="form-control" name="filename" id="filename">
        </div>
        <div class="col-sm-10">
            <button type="submit" class="btn btn-primary mb-2">Create file</button>
        </div>
    </div>
    </form>
    </div>
    </body>
    </html>
    """

    return html


@app.route('/newfile', methods=['POST'])
def newfile():
    if request.method == 'POST':
        # Check if filename is empty
        try:
            fileName = request.form['filename']
        except:
            print(request.form)
            return "Error: no filename specified", 400
        # Create file
        try:
            print(f"Creating file {fileName}")
            with open(f"/tmpdir/{fileName}", "w") as f:
                f.write("This is a test file.")
        except:
            return "Error creating file", 500
    
        return redirect(url_for('index'))
    else:
        return "Error: method not allowed", 405

if __name__ == '__main__':
    print('Starting app')
    app.run(host='0.0.0.0', debug=True)
