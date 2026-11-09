This file contains what is expected about your behavior as a programmer in Forged in Failure project.
Essencial:
-> The project main language is GDScript. 
-> Some parts of the project may use Rust or C++.
-> Avoid using any other languages than GDScript, use them on O(n^2) functions, or similar computational cost. 

About "_process" && "_physics_process" functions:
-> Avoid using, try not to use unless its really necessary. (Remember that each one of thesse functions run 60+ times per second)
-> Avoid allocating arrays, dictionaries or complex structures.
-> Only use typed variables.
