# DB Project
To run the project use the command
```bash
docker compose up -d --build
```
This will detach you from the containers, however you can always keep an eye on them through other tools such as lazydocker or docker desktop. To connect to the cli of the databases use the command

```bash
docker exec -it oracle-global sqlplus pdb_admin/Admin123@//localhost:1521/G_PDB
docker exec -it oracle-site-1 sqlplus pdb_admin/Admin123@//localhost:1522/S1_PDB
docker exec -it oracle-site-2 sqlplus pdb_admin/Admin123@//localhost:1522/S2_PDB
```

# Things to add (12/04/2026)

- [ ] The Synchronization
- [ ] Proper logging (maybe use loki)
- [ ] A better way of handling authorities (Roles didn't work)