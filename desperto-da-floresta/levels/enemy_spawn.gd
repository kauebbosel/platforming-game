# levels/enemy_spawn.gd
class_name EnemySpawn
extends Marker2D
## Ponto de nascimento de UM inimigo numa sala de combate. Coloque dentro do nó "Spawns"
## da sala e escolha o inimigo no Inspetor (Enemy Scene). A posição do ponto é onde o
## inimigo nasce, então um voador vai mais alto que um inimigo de chão.
## Se Enemy Scene ficar vazio, vale o Enemy Scene padrão da própria sala.

@export var enemy_scene: PackedScene
