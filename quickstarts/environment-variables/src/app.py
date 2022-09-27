from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def hello_world():
    html = """
    <!doctype html>
    <html lang="en">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>Environment Variable Quickstart</title>
            <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.2.1/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-iYQeCzEYFbKjA/T2uDLTpkwGzCiq6soy8tYaI1GyVh/UjpbCx/TYkiZhlZB6+fzT" crossorigin="anonymous">
        </head>
        <body>
            <h1>Environment Variables</h1>
            <p>Here are the environment variables set on this container:</p>
            <table class="table table-striped">
                <tr>
                    <th>Name</th><th>Value</th>
                </tr>
    """
    for name, value in os.environ.items():
        html += f"""
        <tr>
        <td>{name}</td>
        <td>{value}</td>
        </tr>
        """
    
    html += """
    </table>
    </body>
    </html>
    """

    return html

if __name__ == '__main__':
    print('Starting app')
    app.run(host='0.0.0.0', debug=True)
