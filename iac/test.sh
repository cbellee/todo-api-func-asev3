# create #1, #2, #3
curl https://q5as3mfg4ljbc-dev-todo-api.azurewebsites.net/api/todos -X POST -d '{"description": "first todo item"}'
curl https://q5as3mfg4ljbc-dev-todo-api.azurewebsites.net/api/todos -X POST -d '{"description": "second todo item"}'
curl https://q5as3mfg4ljbc-dev-todo-api.azurewebsites.net/api/todos -X POST -d '{"description": "third todo item"}'

# update
curl https://q5as3mfg4ljbc-dev-todo-api.azurewebsites.net/api/todos/1 -X PATCH -d '{"description": "really the first todo item"}'

# list all
curl https://q5as3mfg4ljbc-dev-todo-api.azurewebsites.net/api/todos

# complete #3
curl https://q5as3mfg4ljbc-dev-todo-api.azurewebsites.net/api/todos/complete/3 -X PATCH

# list completed
curl https://q5as3mfg4ljbc-dev-todo-api.azurewebsites.net/api/todos/completed

# list incomplete
curl https://q5as3mfg4ljbc-dev-todo-api.azurewebsites.net/api/todos/incomplete

#delete #2
curl https://q5as3mfg4ljbc-dev-todo-api.azurewebsites.net/api/todos/2 -X DELETE

# list all
curl https://q5as3mfg4ljbc-dev-todo-api.azurewebsites.net/api/todos
