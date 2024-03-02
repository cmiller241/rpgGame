extern number time;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    float movement = sin(time + vertex_position.y / 100.0) * pow(vertex_position.y / 100.0, 2.0);
    vertex_position.x += movement * 0.1;
    return transform_projection * vertex_position;
}