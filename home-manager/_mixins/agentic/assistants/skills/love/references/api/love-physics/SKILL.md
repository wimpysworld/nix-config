---
name: love-physics
description: Can simulate 2D rigid body physics in a realistic manner. This module is based on Box2D, and this API corresponds to the Box2D API as closely as possible. Use this skill when working with physics operations, collision detection, rigid body dynamics, or any physics-related operations in LÖVE games.
license: MIT
metadata:
  author: Ron Dekker <rondekker.nl>
---

## When to use this skill
Can simulate 2D rigid body physics in a realistic manner. This module is based on Box2D, and this API corresponds to the Box2D API as closely as possible. Use this skill when working with physics operations, collision detection, rigid body dynamics, or any physics-related operations in LÖVE games.

## Common use cases
- Creating physics-based game mechanics
- Implementing realistic object interactions
- Handling collision detection and response
- Working with rigid bodies and constraints
- Simulating real-world physics behavior

## Functions

- `love.physics.getDistance(fixture1: Fixture, fixture2: Fixture) -> distance: number, x1: number, y1: number, x2: number, y2: number`: Returns the two closest points between two fixtures and their distance.
- `love.physics.getMeter() -> scale: number`: Returns the meter scale factor. All coordinates in the physics module are divided by this number, creating a convenient way to draw the objects directly to the screen without the need for graphics transformations. It is recommended to create shapes no larger than 10 times the scale. This is important because Box2D is tuned to work well with shape sizes from 0.1 to 10 meters.
- `love.physics.newBody(world: World, x: number, y: number, type: BodyType) -> body: Body`: Creates a new body. There are three types of bodies.  * Static bodies do not move, have a infinite mass, and can be used for level boundaries.  * Dynamic bodies are the main actors in the simulation, they collide with everything.  * Kinematic bodies do not react to forces and only collide with dynamic bodies. The mass of the body gets calculated when a Fixture is attached or removed, but can be changed at any time with Body:setMass or Body:resetMassData.
- `love.physics.newChainShape` - Creates a new ChainShape.
  - `love.physics.newChainShape(loop: boolean, x1: number, y1: number, x2: number, y2: number, ...: number) -> shape: ChainShape`: No description
  - `love.physics.newChainShape(loop: boolean, points: table) -> shape: ChainShape`: No description
- `love.physics.newCircleShape` - Creates a new CircleShape.
  - `love.physics.newCircleShape(radius: number) -> shape: CircleShape`: No description
  - `love.physics.newCircleShape(x: number, y: number, radius: number) -> shape: CircleShape`: No description
- `love.physics.newDistanceJoint(body1: Body, body2: Body, x1: number, y1: number, x2: number, y2: number, collideConnected: boolean) -> joint: DistanceJoint`: Creates a DistanceJoint between two bodies. This joint constrains the distance between two points on two bodies to be constant. These two points are specified in world coordinates and the two bodies are assumed to be in place when this joint is created. The first anchor point is connected to the first body and the second to the second body, and the points define the length of the distance joint.
- `love.physics.newEdgeShape(x1: number, y1: number, x2: number, y2: number) -> shape: EdgeShape`: Creates a new EdgeShape.
- `love.physics.newFixture(body: Body, shape: Shape, density: number) -> fixture: Fixture`: Creates and attaches a Fixture to a body. Note that the Shape object is copied rather than kept as a reference when the Fixture is created. To get the Shape object that the Fixture owns, use Fixture:getShape.
- `love.physics.newFrictionJoint` - Create a friction joint between two bodies. A FrictionJoint applies friction to a body.
  - `love.physics.newFrictionJoint(body1: Body, body2: Body, x: number, y: number, collideConnected: boolean) -> joint: FrictionJoint`: No description
  - `love.physics.newFrictionJoint(body1: Body, body2: Body, x1: number, y1: number, x2: number, y2: number, collideConnected: boolean) -> joint: FrictionJoint`: No description
- `love.physics.newGearJoint(joint1: Joint, joint2: Joint, ratio: number, collideConnected: boolean) -> joint: GearJoint`: Create a GearJoint connecting two Joints. The gear joint connects two joints that must be either  prismatic or  revolute joints. Using this joint requires that the joints it uses connect their respective bodies to the ground and have the ground as the first body. When destroying the bodies and joints you must make sure you destroy the gear joint before the other joints. The gear joint has a ratio the determines how the angular or distance values of the connected joints relate to each other. The formula coordinate1 + ratio * coordinate2 always has a constant value that is set when the gear joint is created.
- `love.physics.newMotorJoint` - Creates a joint between two bodies which controls the relative motion between them. Position and rotation offsets can be specified once the MotorJoint has been created, as well as the maximum motor force and torque that will be be applied to reach the target offsets.
  - `love.physics.newMotorJoint(body1: Body, body2: Body, correctionFactor: number) -> joint: MotorJoint`: No description
  - `love.physics.newMotorJoint(body1: Body, body2: Body, correctionFactor: number, collideConnected: boolean) -> joint: MotorJoint`: No description
- `love.physics.newMouseJoint(body: Body, x: number, y: number) -> joint: MouseJoint`: Create a joint between a body and the mouse. This joint actually connects the body to a fixed point in the world. To make it follow the mouse, the fixed point must be updated every timestep (example below). The advantage of using a MouseJoint instead of just changing a body position directly is that collisions and reactions to other joints are handled by the physics engine. 
- `love.physics.newPolygonShape` - Creates a new PolygonShape. This shape can have 8 vertices at most, and must form a convex shape.
  - `love.physics.newPolygonShape(x1: number, y1: number, x2: number, y2: number, x3: number, y3: number, ...: number) -> shape: PolygonShape`: No description
  - `love.physics.newPolygonShape(vertices: table) -> shape: PolygonShape`: No description
- `love.physics.newPrismaticJoint` - Creates a PrismaticJoint between two bodies. A prismatic joint constrains two bodies to move relatively to each other on a specified axis. It does not allow for relative rotation. Its definition and operation are similar to a  revolute joint, but with translation and force substituted for angle and torque.
  - `love.physics.newPrismaticJoint(body1: Body, body2: Body, x: number, y: number, ax: number, ay: number, collideConnected: boolean) -> joint: PrismaticJoint`: No description
  - `love.physics.newPrismaticJoint(body1: Body, body2: Body, x1: number, y1: number, x2: number, y2: number, ax: number, ay: number, collideConnected: boolean) -> joint: PrismaticJoint`: No description
  - `love.physics.newPrismaticJoint(body1: Body, body2: Body, x1: number, y1: number, x2: number, y2: number, ax: number, ay: number, collideConnected: boolean, referenceAngle: number) -> joint: PrismaticJoint`: No description
- `love.physics.newPulleyJoint(body1: Body, body2: Body, gx1: number, gy1: number, gx2: number, gy2: number, x1: number, y1: number, x2: number, y2: number, ratio: number, collideConnected: boolean) -> joint: PulleyJoint`: Creates a PulleyJoint to join two bodies to each other and the ground. The pulley joint simulates a pulley with an optional block and tackle. If the ratio parameter has a value different from one, then the simulated rope extends faster on one side than the other. In a pulley joint the total length of the simulated rope is the constant length1 + ratio * length2, which is set when the pulley joint is created. Pulley joints can behave unpredictably if one side is fully extended. It is recommended that the method  setMaxLengths  be used to constrain the maximum lengths each side can attain.
- `love.physics.newRectangleShape` - Shorthand for creating rectangular PolygonShapes.  By default, the local origin is located at the '''center''' of the rectangle as opposed to the top left for graphics.
  - `love.physics.newRectangleShape(width: number, height: number) -> shape: PolygonShape`: No description
  - `love.physics.newRectangleShape(x: number, y: number, width: number, height: number, angle: number) -> shape: PolygonShape`: No description
- `love.physics.newRevoluteJoint` - Creates a pivot joint between two bodies. This joint connects two bodies to a point around which they can pivot.
  - `love.physics.newRevoluteJoint(body1: Body, body2: Body, x: number, y: number, collideConnected: boolean) -> joint: RevoluteJoint`: No description
  - `love.physics.newRevoluteJoint(body1: Body, body2: Body, x1: number, y1: number, x2: number, y2: number, collideConnected: boolean, referenceAngle: number) -> joint: RevoluteJoint`: No description
- `love.physics.newRopeJoint(body1: Body, body2: Body, x1: number, y1: number, x2: number, y2: number, maxLength: number, collideConnected: boolean) -> joint: RopeJoint`: Creates a joint between two bodies. Its only function is enforcing a max distance between these bodies.
- `love.physics.newWeldJoint` - Creates a constraint joint between two bodies. A WeldJoint essentially glues two bodies together. The constraint is a bit soft, however, due to Box2D's iterative solver.
  - `love.physics.newWeldJoint(body1: Body, body2: Body, x: number, y: number, collideConnected: boolean) -> joint: WeldJoint`: No description
  - `love.physics.newWeldJoint(body1: Body, body2: Body, x1: number, y1: number, x2: number, y2: number, collideConnected: boolean) -> joint: WeldJoint`: No description
  - `love.physics.newWeldJoint(body1: Body, body2: Body, x1: number, y1: number, x2: number, y2: number, collideConnected: boolean, referenceAngle: number) -> joint: WeldJoint`: No description
- `love.physics.newWheelJoint` - Creates a wheel joint.
  - `love.physics.newWheelJoint(body1: Body, body2: Body, x: number, y: number, ax: number, ay: number, collideConnected: boolean) -> joint: WheelJoint`: No description
  - `love.physics.newWheelJoint(body1: Body, body2: Body, x1: number, y1: number, x2: number, y2: number, ax: number, ay: number, collideConnected: boolean) -> joint: WheelJoint`: No description
- `love.physics.newWorld(xg: number, yg: number, sleep: boolean) -> world: World`: Creates a new World.
- `love.physics.setMeter(scale: number)`: Sets the pixels to meter scale factor. All coordinates in the physics module are divided by this number and converted to meters, and it creates a convenient way to draw the objects directly to the screen without the need for graphics transformations. It is recommended to create shapes no larger than 10 times the scale. This is important because Box2D is tuned to work well with shape sizes from 0.1 to 10 meters. The default meter scale is 30.

## Types

- `Body`: Bodies are objects with velocity and position.
  - `love.Body.applyAngularImpulse(impulse: number)`: Applies an angular impulse to a body. This makes a single, instantaneous addition to the body momentum. A body with with a larger mass will react less. The reaction does '''not''' depend on the timestep, and is equivalent to applying a force continuously for 1 second. Impulses are best used to give a single push to a body. For a continuous push to a body it is better to use Body:applyForce.
  - `love.Body.applyForce(fx: number, fy: number)`: Apply force to a Body. A force pushes a body in a direction. A body with with a larger mass will react less. The reaction also depends on how long a force is applied: since the force acts continuously over the entire timestep, a short timestep will only push the body for a short time. Thus forces are best used for many timesteps to give a continuous push to a body (like gravity). For a single push that is independent of timestep, it is better to use Body:applyLinearImpulse. If the position to apply the force is not given, it will act on the center of mass of the body. The part of the force not directed towards the center of mass will cause the body to spin (and depends on the rotational inertia). Note that the force components and position must be given in world coordinates.
  - `love.Body.applyLinearImpulse(ix: number, iy: number)`: Applies an impulse to a body. This makes a single, instantaneous addition to the body momentum. An impulse pushes a body in a direction. A body with with a larger mass will react less. The reaction does '''not''' depend on the timestep, and is equivalent to applying a force continuously for 1 second. Impulses are best used to give a single push to a body. For a continuous push to a body it is better to use Body:applyForce. If the position to apply the impulse is not given, it will act on the center of mass of the body. The part of the impulse not directed towards the center of mass will cause the body to spin (and depends on the rotational inertia).  Note that the impulse components and position must be given in world coordinates.
  - `love.Body.applyTorque(torque: number)`: Apply torque to a body. Torque is like a force that will change the angular velocity (spin) of a body. The effect will depend on the rotational inertia a body has.
  - `love.Body.destroy()`: Explicitly destroys the Body and all fixtures and joints attached to it. An error will occur if you attempt to use the object after calling this function. In 0.7.2, when you don't have time to wait for garbage collection, this function may be used to free the object immediately.
  - `love.Body.getAngle() -> angle: number`: Get the angle of the body. The angle is measured in radians. If you need to transform it to degrees, use math.deg. A value of 0 radians will mean 'looking to the right'. Although radians increase counter-clockwise, the y axis points down so it becomes ''clockwise'' from our point of view.
  - `love.Body.getAngularDamping() -> damping: number`: Gets the Angular damping of the Body The angular damping is the ''rate of decrease of the angular velocity over time'': A spinning body with no damping and no external forces will continue spinning indefinitely. A spinning body with damping will gradually stop spinning. Damping is not the same as friction - they can be modelled together. However, only damping is provided by Box2D (and LOVE). Damping parameters should be between 0 and infinity, with 0 meaning no damping, and infinity meaning full damping. Normally you will use a damping value between 0 and 0.1.
  - `love.Body.getAngularVelocity() -> w: number`: Get the angular velocity of the Body. The angular velocity is the ''rate of change of angle over time''. It is changed in World:update by applying torques, off centre forces/impulses, and angular damping. It can be set directly with Body:setAngularVelocity. If you need the ''rate of change of position over time'', use Body:getLinearVelocity.
  - `love.Body.getContacts() -> contacts: table`: Gets a list of all Contacts attached to the Body.
  - `love.Body.getFixtures() -> fixtures: table`: Returns a table with all fixtures.
  - `love.Body.getGravityScale() -> scale: number`: Returns the gravity scale factor.
  - `love.Body.getInertia() -> inertia: number`: Gets the rotational inertia of the body. The rotational inertia is how hard is it to make the body spin.
  - `love.Body.getJoints() -> joints: table`: Returns a table containing the Joints attached to this Body.
  - `love.Body.getLinearDamping() -> damping: number`: Gets the linear damping of the Body. The linear damping is the ''rate of decrease of the linear velocity over time''. A moving body with no damping and no external forces will continue moving indefinitely, as is the case in space. A moving body with damping will gradually stop moving. Damping is not the same as friction - they can be modelled together.
  - `love.Body.getLinearVelocity() -> x: number, y: number`: Gets the linear velocity of the Body from its center of mass. The linear velocity is the ''rate of change of position over time''. If you need the ''rate of change of angle over time'', use Body:getAngularVelocity. If you need to get the linear velocity of a point different from the center of mass: *  Body:getLinearVelocityFromLocalPoint allows you to specify the point in local coordinates. *  Body:getLinearVelocityFromWorldPoint allows you to specify the point in world coordinates. See page 136 of 'Essential Mathematics for Games and Interactive Applications' for definitions of local and world coordinates.
  - `love.Body.getLinearVelocityFromLocalPoint(x: number, y: number) -> vx: number, vy: number`: Get the linear velocity of a point on the body. The linear velocity for a point on the body is the velocity of the body center of mass plus the velocity at that point from the body spinning. The point on the body must given in local coordinates. Use Body:getLinearVelocityFromWorldPoint to specify this with world coordinates.
  - `love.Body.getLinearVelocityFromWorldPoint(x: number, y: number) -> vx: number, vy: number`: Get the linear velocity of a point on the body. The linear velocity for a point on the body is the velocity of the body center of mass plus the velocity at that point from the body spinning. The point on the body must given in world coordinates. Use Body:getLinearVelocityFromLocalPoint to specify this with local coordinates.
  - `love.Body.getLocalCenter() -> x: number, y: number`: Get the center of mass position in local coordinates. Use Body:getWorldCenter to get the center of mass in world coordinates.
  - `love.Body.getLocalPoint(worldX: number, worldY: number) -> localX: number, localY: number`: Transform a point from world coordinates to local coordinates.
  - `love.Body.getLocalPoints(x1: number, y1: number, x2: number, y2: number, ...: number) -> x1: number, y1: number, x2: number, y2: number, ...: number`: Transforms multiple points from world coordinates to local coordinates.
  - `love.Body.getLocalVector(worldX: number, worldY: number) -> localX: number, localY: number`: Transform a vector from world coordinates to local coordinates.
  - `love.Body.getMass() -> mass: number`: Get the mass of the body. Static bodies always have a mass of 0.
  - `love.Body.getMassData() -> x: number, y: number, mass: number, inertia: number`: Returns the mass, its center, and the rotational inertia.
  - `love.Body.getPosition() -> x: number, y: number`: Get the position of the body. Note that this may not be the center of mass of the body.
  - `love.Body.getTransform() -> x: number, y: number, angle: number`: Get the position and angle of the body. Note that the position may not be the center of mass of the body. An angle of 0 radians will mean 'looking to the right'. Although radians increase counter-clockwise, the y axis points down so it becomes clockwise from our point of view.
  - `love.Body.getType() -> type: BodyType`: Returns the type of the body.
  - `love.Body.getUserData() -> value: any`: Returns the Lua value associated with this Body.
  - `love.Body.getWorld() -> world: World`: Gets the World the body lives in.
  - `love.Body.getWorldCenter() -> x: number, y: number`: Get the center of mass position in world coordinates. Use Body:getLocalCenter to get the center of mass in local coordinates.
  - `love.Body.getWorldPoint(localX: number, localY: number) -> worldX: number, worldY: number`: Transform a point from local coordinates to world coordinates.
  - `love.Body.getWorldPoints(x1: number, y1: number, x2: number, y2: number) -> x1: number, y1: number, x2: number, y2: number`: Transforms multiple points from local coordinates to world coordinates.
  - `love.Body.getWorldVector(localX: number, localY: number) -> worldX: number, worldY: number`: Transform a vector from local coordinates to world coordinates.
  - `love.Body.getX() -> x: number`: Get the x position of the body in world coordinates.
  - `love.Body.getY() -> y: number`: Get the y position of the body in world coordinates.
  - `love.Body.isActive() -> status: boolean`: Returns whether the body is actively used in the simulation.
  - `love.Body.isAwake() -> status: boolean`: Returns the sleep status of the body.
  - `love.Body.isBullet() -> status: boolean`: Get the bullet status of a body. There are two methods to check for body collisions: *  at their location when the world is updated (default) *  using continuous collision detection (CCD) The default method is efficient, but a body moving very quickly may sometimes jump over another body without producing a collision. A body that is set as a bullet will use CCD. This is less efficient, but is guaranteed not to jump when moving quickly. Note that static bodies (with zero mass) always use CCD, so your walls will not let a fast moving body pass through even if it is not a bullet.
  - `love.Body.isDestroyed() -> destroyed: boolean`: Gets whether the Body is destroyed. Destroyed bodies cannot be used.
  - `love.Body.isFixedRotation() -> fixed: boolean`: Returns whether the body rotation is locked.
  - `love.Body.isSleepingAllowed() -> allowed: boolean`: Returns the sleeping behaviour of the body.
  - `love.Body.isTouching(otherbody: Body) -> touching: boolean`: Gets whether the Body is touching the given other Body.
  - `love.Body.resetMassData()`: Resets the mass of the body by recalculating it from the mass properties of the fixtures.
  - `love.Body.setActive(active: boolean)`: Sets whether the body is active in the world. An inactive body does not take part in the simulation. It will not move or cause any collisions.
  - `love.Body.setAngle(angle: number)`: Set the angle of the body. The angle is measured in radians. If you need to transform it from degrees, use math.rad. A value of 0 radians will mean 'looking to the right'. Although radians increase counter-clockwise, the y axis points down so it becomes ''clockwise'' from our point of view. It is possible to cause a collision with another body by changing its angle. 
  - `love.Body.setAngularDamping(damping: number)`: Sets the angular damping of a Body See Body:getAngularDamping for a definition of angular damping. Angular damping can take any value from 0 to infinity. It is recommended to stay between 0 and 0.1, though. Other values will look unrealistic.
  - `love.Body.setAngularVelocity(w: number)`: Sets the angular velocity of a Body. The angular velocity is the ''rate of change of angle over time''. This function will not accumulate anything; any impulses previously applied since the last call to World:update will be lost. 
  - `love.Body.setAwake(awake: boolean)`: Wakes the body up or puts it to sleep.
  - `love.Body.setBullet(status: boolean)`: Set the bullet status of a body. There are two methods to check for body collisions: *  at their location when the world is updated (default) *  using continuous collision detection (CCD) The default method is efficient, but a body moving very quickly may sometimes jump over another body without producing a collision. A body that is set as a bullet will use CCD. This is less efficient, but is guaranteed not to jump when moving quickly. Note that static bodies (with zero mass) always use CCD, so your walls will not let a fast moving body pass through even if it is not a bullet.
  - `love.Body.setFixedRotation(isFixed: boolean)`: Set whether a body has fixed rotation. Bodies with fixed rotation don't vary the speed at which they rotate. Calling this function causes the mass to be reset. 
  - `love.Body.setGravityScale(scale: number)`: Sets a new gravity scale factor for the body.
  - `love.Body.setInertia(inertia: number)`: Set the inertia of a body.
  - `love.Body.setLinearDamping(ld: number)`: Sets the linear damping of a Body See Body:getLinearDamping for a definition of linear damping. Linear damping can take any value from 0 to infinity. It is recommended to stay between 0 and 0.1, though. Other values will make the objects look 'floaty'(if gravity is enabled).
  - `love.Body.setLinearVelocity(x: number, y: number)`: Sets a new linear velocity for the Body. This function will not accumulate anything; any impulses previously applied since the last call to World:update will be lost.
  - `love.Body.setMass(mass: number)`: Sets a new body mass.
  - `love.Body.setMassData(x: number, y: number, mass: number, inertia: number)`: Overrides the calculated mass data.
  - `love.Body.setPosition(x: number, y: number)`: Set the position of the body. Note that this may not be the center of mass of the body. This function cannot wake up the body.
  - `love.Body.setSleepingAllowed(allowed: boolean)`: Sets the sleeping behaviour of the body. Should sleeping be allowed, a body at rest will automatically sleep. A sleeping body is not simulated unless it collided with an awake body. Be wary that one can end up with a situation like a floating sleeping body if the floor was removed.
  - `love.Body.setTransform(x: number, y: number, angle: number)`: Set the position and angle of the body. Note that the position may not be the center of mass of the body. An angle of 0 radians will mean 'looking to the right'. Although radians increase counter-clockwise, the y axis points down so it becomes clockwise from our point of view. This function cannot wake up the body.
  - `love.Body.setType(type: BodyType)`: Sets a new body type.
  - `love.Body.setUserData(value: any)`: Associates a Lua value with the Body. To delete the reference, explicitly pass nil.
  - `love.Body.setX(x: number)`: Set the x position of the body. This function cannot wake up the body. 
  - `love.Body.setY(y: number)`: Set the y position of the body. This function cannot wake up the body. 

- `ChainShape`: A ChainShape consists of multiple line segments. It can be used to create the boundaries of your terrain. The shape does not have volume and can only collide with PolygonShape and CircleShape. Unlike the PolygonShape, the ChainShape does not have a vertices limit or has to form a convex shape, but self intersections are not supported.
  - `love.ChainShape.getChildEdge(index: number) -> shape: EdgeShape`: Returns a child of the shape as an EdgeShape.
  - `love.ChainShape.getNextVertex() -> x: number, y: number`: Gets the vertex that establishes a connection to the next shape. Setting next and previous ChainShape vertices can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.
  - `love.ChainShape.getPoint(index: number) -> x: number, y: number`: Returns a point of the shape.
  - `love.ChainShape.getPoints() -> x1: number, y1: number, x2: number, y2: number`: Returns all points of the shape.
  - `love.ChainShape.getPreviousVertex() -> x: number, y: number`: Gets the vertex that establishes a connection to the previous shape. Setting next and previous ChainShape vertices can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.
  - `love.ChainShape.getVertexCount() -> count: number`: Returns the number of vertices the shape has.
  - `love.ChainShape.setNextVertex(x: number, y: number)`: Sets a vertex that establishes a connection to the next shape. This can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.
  - `love.ChainShape.setPreviousVertex(x: number, y: number)`: Sets a vertex that establishes a connection to the previous shape. This can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.

- `CircleShape`: Circle extends Shape and adds a radius and a local position.
  - `love.CircleShape.getPoint() -> x: number, y: number`: Gets the center point of the circle shape.
  - `love.CircleShape.getRadius() -> radius: number`: Gets the radius of the circle shape.
  - `love.CircleShape.setPoint(x: number, y: number)`: Sets the location of the center of the circle shape.
  - `love.CircleShape.setRadius(radius: number)`: Sets the radius of the circle.

- `Contact`: Contacts are objects created to manage collisions in worlds.
  - `love.Contact.getChildren() -> indexA: number, indexB: number`: Gets the child indices of the shapes of the two colliding fixtures. For ChainShapes, an index of 1 is the first edge in the chain. Used together with Fixture:rayCast or ChainShape:getChildEdge.
  - `love.Contact.getFixtures() -> fixtureA: Fixture, fixtureB: Fixture`: Gets the two Fixtures that hold the shapes that are in contact.
  - `love.Contact.getFriction() -> friction: number`: Get the friction between two shapes that are in contact.
  - `love.Contact.getNormal() -> nx: number, ny: number`: Get the normal vector between two shapes that are in contact. This function returns the coordinates of a unit vector that points from the first shape to the second.
  - `love.Contact.getPositions() -> x1: number, y1: number, x2: number, y2: number`: Returns the contact points of the two colliding fixtures. There can be one or two points.
  - `love.Contact.getRestitution() -> restitution: number`: Get the restitution between two shapes that are in contact.
  - `love.Contact.isEnabled() -> enabled: boolean`: Returns whether the contact is enabled. The collision will be ignored if a contact gets disabled in the preSolve callback.
  - `love.Contact.isTouching() -> touching: boolean`: Returns whether the two colliding fixtures are touching each other.
  - `love.Contact.resetFriction()`: Resets the contact friction to the mixture value of both fixtures.
  - `love.Contact.resetRestitution()`: Resets the contact restitution to the mixture value of both fixtures.
  - `love.Contact.setEnabled(enabled: boolean)`: Enables or disables the contact.
  - `love.Contact.setFriction(friction: number)`: Sets the contact friction.
  - `love.Contact.setRestitution(restitution: number)`: Sets the contact restitution.

- `DistanceJoint`: Keeps two bodies at the same distance.
  - `love.DistanceJoint.getDampingRatio() -> ratio: number`: Gets the damping ratio.
  - `love.DistanceJoint.getFrequency() -> Hz: number`: Gets the response speed.
  - `love.DistanceJoint.getLength() -> l: number`: Gets the equilibrium distance between the two Bodies.
  - `love.DistanceJoint.setDampingRatio(ratio: number)`: Sets the damping ratio.
  - `love.DistanceJoint.setFrequency(Hz: number)`: Sets the response speed.
  - `love.DistanceJoint.setLength(l: number)`: Sets the equilibrium distance between the two Bodies.

- `EdgeShape`: A EdgeShape is a line segment. They can be used to create the boundaries of your terrain. The shape does not have volume and can only collide with PolygonShape and CircleShape.
  - `love.EdgeShape.getNextVertex() -> x: number, y: number`: Gets the vertex that establishes a connection to the next shape. Setting next and previous EdgeShape vertices can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.
  - `love.EdgeShape.getPoints() -> x1: number, y1: number, x2: number, y2: number`: Returns the local coordinates of the edge points.
  - `love.EdgeShape.getPreviousVertex() -> x: number, y: number`: Gets the vertex that establishes a connection to the previous shape. Setting next and previous EdgeShape vertices can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.
  - `love.EdgeShape.setNextVertex(x: number, y: number)`: Sets a vertex that establishes a connection to the next shape. This can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.
  - `love.EdgeShape.setPreviousVertex(x: number, y: number)`: Sets a vertex that establishes a connection to the previous shape. This can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.

- `Fixture`: Fixtures attach shapes to bodies.
  - `love.Fixture.destroy()`: Destroys the fixture.
  - `love.Fixture.getBody() -> body: Body`: Returns the body to which the fixture is attached.
  - `love.Fixture.getBoundingBox(index: number) -> topLeftX: number, topLeftY: number, bottomRightX: number, bottomRightY: number`: Returns the points of the fixture bounding box. In case the fixture has multiple children a 1-based index can be specified. For example, a fixture will have multiple children with a chain shape.
  - `love.Fixture.getCategory() -> ...: number`: Returns the categories the fixture belongs to.
  - `love.Fixture.getDensity() -> density: number`: Returns the density of the fixture.
  - `love.Fixture.getFilterData() -> categories: number, mask: number, group: number`: Returns the filter data of the fixture. Categories and masks are encoded as the bits of a 16-bit integer.
  - `love.Fixture.getFriction() -> friction: number`: Returns the friction of the fixture.
  - `love.Fixture.getGroupIndex() -> group: number`: Returns the group the fixture belongs to. Fixtures with the same group will always collide if the group is positive or never collide if it's negative. The group zero means no group. The groups range from -32768 to 32767.
  - `love.Fixture.getMask() -> ...: number`: Returns which categories this fixture should '''NOT''' collide with.
  - `love.Fixture.getMassData() -> x: number, y: number, mass: number, inertia: number`: Returns the mass, its center and the rotational inertia.
  - `love.Fixture.getRestitution() -> restitution: number`: Returns the restitution of the fixture.
  - `love.Fixture.getShape() -> shape: Shape`: Returns the shape of the fixture. This shape is a reference to the actual data used in the simulation. It's possible to change its values between timesteps.
  - `love.Fixture.getUserData() -> value: any`: Returns the Lua value associated with this fixture.
  - `love.Fixture.isDestroyed() -> destroyed: boolean`: Gets whether the Fixture is destroyed. Destroyed fixtures cannot be used.
  - `love.Fixture.isSensor() -> sensor: boolean`: Returns whether the fixture is a sensor.
  - `love.Fixture.rayCast(x1: number, y1: number, x2: number, y2: number, maxFraction: number, childIndex: number) -> xn: number, yn: number, fraction: number`: Casts a ray against the shape of the fixture and returns the surface normal vector and the line position where the ray hit. If the ray missed the shape, nil will be returned. The ray starts on the first point of the input line and goes towards the second point of the line. The fifth argument is the maximum distance the ray is going to travel as a scale factor of the input line length. The childIndex parameter is used to specify which child of a parent shape, such as a ChainShape, will be ray casted. For ChainShapes, the index of 1 is the first edge on the chain. Ray casting a parent shape will only test the child specified so if you want to test every shape of the parent, you must loop through all of its children. The world position of the impact can be calculated by multiplying the line vector with the third return value and adding it to the line starting point. hitx, hity = x1 + (x2 - x1) * fraction, y1 + (y2 - y1) * fraction
  - `love.Fixture.setCategory(...: number)`: Sets the categories the fixture belongs to. There can be up to 16 categories represented as a number from 1 to 16. All fixture's default category is 1.
  - `love.Fixture.setDensity(density: number)`: Sets the density of the fixture. Call Body:resetMassData if this needs to take effect immediately.
  - `love.Fixture.setFilterData(categories: number, mask: number, group: number)`: Sets the filter data of the fixture. Groups, categories, and mask can be used to define the collision behaviour of the fixture. If two fixtures are in the same group they either always collide if the group is positive, or never collide if it's negative. If the group is zero or they do not match, then the contact filter checks if the fixtures select a category of the other fixture with their masks. The fixtures do not collide if that's not the case. If they do have each other's categories selected, the return value of the custom contact filter will be used. They always collide if none was set. There can be up to 16 categories. Categories and masks are encoded as the bits of a 16-bit integer. When created, prior to calling this function, all fixtures have category set to 1, mask set to 65535 (all categories) and group set to 0. This function allows setting all filter data for a fixture at once. To set only the categories, the mask or the group, you can use Fixture:setCategory, Fixture:setMask or Fixture:setGroupIndex respectively.
  - `love.Fixture.setFriction(friction: number)`: Sets the friction of the fixture. Friction determines how shapes react when they 'slide' along other shapes. Low friction indicates a slippery surface, like ice, while high friction indicates a rough surface, like concrete. Range: 0.0 - 1.0.
  - `love.Fixture.setGroupIndex(group: number)`: Sets the group the fixture belongs to. Fixtures with the same group will always collide if the group is positive or never collide if it's negative. The group zero means no group. The groups range from -32768 to 32767.
  - `love.Fixture.setMask(...: number)`: Sets the category mask of the fixture. There can be up to 16 categories represented as a number from 1 to 16. This fixture will '''NOT''' collide with the fixtures that are in the selected categories if the other fixture also has a category of this fixture selected.
  - `love.Fixture.setRestitution(restitution: number)`: Sets the restitution of the fixture.
  - `love.Fixture.setSensor(sensor: boolean)`: Sets whether the fixture should act as a sensor. Sensors do not cause collision responses, but the begin-contact and end-contact World callbacks will still be called for this fixture.
  - `love.Fixture.setUserData(value: any)`: Associates a Lua value with the fixture. To delete the reference, explicitly pass nil.
  - `love.Fixture.testPoint(x: number, y: number) -> isInside: boolean`: Checks if a point is inside the shape of the fixture.

- `FrictionJoint`: A FrictionJoint applies friction to a body.
  - `love.FrictionJoint.getMaxForce() -> force: number`: Gets the maximum friction force in Newtons.
  - `love.FrictionJoint.getMaxTorque() -> torque: number`: Gets the maximum friction torque in Newton-meters.
  - `love.FrictionJoint.setMaxForce(maxForce: number)`: Sets the maximum friction force in Newtons.
  - `love.FrictionJoint.setMaxTorque(torque: number)`: Sets the maximum friction torque in Newton-meters.

- `GearJoint`: Keeps bodies together in such a way that they act like gears.
  - `love.GearJoint.getJoints() -> joint1: Joint, joint2: Joint`: Get the Joints connected by this GearJoint.
  - `love.GearJoint.getRatio() -> ratio: number`: Get the ratio of a gear joint.
  - `love.GearJoint.setRatio(ratio: number)`: Set the ratio of a gear joint.

- `Joint`: Attach multiple bodies together to interact in unique ways.
  - `love.Joint.destroy()`: Explicitly destroys the Joint. An error will occur if you attempt to use the object after calling this function. In 0.7.2, when you don't have time to wait for garbage collection, this function  may be used to free the object immediately.
  - `love.Joint.getAnchors() -> x1: number, y1: number, x2: number, y2: number`: Get the anchor points of the joint.
  - `love.Joint.getBodies() -> bodyA: Body, bodyB: Body`: Gets the bodies that the Joint is attached to.
  - `love.Joint.getCollideConnected() -> c: boolean`: Gets whether the connected Bodies collide.
  - `love.Joint.getReactionForce(x: number) -> x: number, y: number`: Returns the reaction force in newtons on the second body
  - `love.Joint.getReactionTorque(invdt: number) -> torque: number`: Returns the reaction torque on the second body.
  - `love.Joint.getType() -> type: JointType`: Gets a string representing the type.
  - `love.Joint.getUserData() -> value: any`: Returns the Lua value associated with this Joint.
  - `love.Joint.isDestroyed() -> destroyed: boolean`: Gets whether the Joint is destroyed. Destroyed joints cannot be used.
  - `love.Joint.setUserData(value: any)`: Associates a Lua value with the Joint. To delete the reference, explicitly pass nil.

- `MotorJoint`: Controls the relative motion between two Bodies. Position and rotation offsets can be specified, as well as the maximum motor force and torque that will be applied to reach the target offsets.
  - `love.MotorJoint.getAngularOffset() -> angleoffset: number`: Gets the target angular offset between the two Bodies the Joint is attached to.
  - `love.MotorJoint.getLinearOffset() -> x: number, y: number`: Gets the target linear offset between the two Bodies the Joint is attached to.
  - `love.MotorJoint.setAngularOffset(angleoffset: number)`: Sets the target angluar offset between the two Bodies the Joint is attached to.
  - `love.MotorJoint.setLinearOffset(x: number, y: number)`: Sets the target linear offset between the two Bodies the Joint is attached to.

- `MouseJoint`: For controlling objects with the mouse.
  - `love.MouseJoint.getDampingRatio() -> ratio: number`: Returns the damping ratio.
  - `love.MouseJoint.getFrequency() -> freq: number`: Returns the frequency.
  - `love.MouseJoint.getMaxForce() -> f: number`: Gets the highest allowed force.
  - `love.MouseJoint.getTarget() -> x: number, y: number`: Gets the target point.
  - `love.MouseJoint.setDampingRatio(ratio: number)`: Sets a new damping ratio.
  - `love.MouseJoint.setFrequency(freq: number)`: Sets a new frequency.
  - `love.MouseJoint.setMaxForce(f: number)`: Sets the highest allowed force.
  - `love.MouseJoint.setTarget(x: number, y: number)`: Sets the target point.

- `PolygonShape`: A PolygonShape is a convex polygon with up to 8 vertices.
  - `love.PolygonShape.getPoints() -> x1: number, y1: number, x2: number, y2: number`: Get the local coordinates of the polygon's vertices. This function has a variable number of return values. It can be used in a nested fashion with love.graphics.polygon.

- `PrismaticJoint`: Restricts relative motion between Bodies to one shared axis.
  - `love.PrismaticJoint.areLimitsEnabled() -> enabled: boolean`: Checks whether the limits are enabled.
  - `love.PrismaticJoint.getAxis() -> x: number, y: number`: Gets the world-space axis vector of the Prismatic Joint.
  - `love.PrismaticJoint.getJointSpeed() -> s: number`: Get the current joint angle speed.
  - `love.PrismaticJoint.getJointTranslation() -> t: number`: Get the current joint translation.
  - `love.PrismaticJoint.getLimits() -> lower: number, upper: number`: Gets the joint limits.
  - `love.PrismaticJoint.getLowerLimit() -> lower: number`: Gets the lower limit.
  - `love.PrismaticJoint.getMaxMotorForce() -> f: number`: Gets the maximum motor force.
  - `love.PrismaticJoint.getMotorForce(invdt: number) -> force: number`: Returns the current motor force.
  - `love.PrismaticJoint.getMotorSpeed() -> s: number`: Gets the motor speed.
  - `love.PrismaticJoint.getReferenceAngle() -> angle: number`: Gets the reference angle.
  - `love.PrismaticJoint.getUpperLimit() -> upper: number`: Gets the upper limit.
  - `love.PrismaticJoint.isMotorEnabled() -> enabled: boolean`: Checks whether the motor is enabled.
  - `love.PrismaticJoint.setLimits(lower: number, upper: number)`: Sets the limits.
  - `love.PrismaticJoint.setLimitsEnabled() -> enable: boolean`: Enables/disables the joint limit.
  - `love.PrismaticJoint.setLowerLimit(lower: number)`: Sets the lower limit.
  - `love.PrismaticJoint.setMaxMotorForce(f: number)`: Set the maximum motor force.
  - `love.PrismaticJoint.setMotorEnabled(enable: boolean)`: Enables/disables the joint motor.
  - `love.PrismaticJoint.setMotorSpeed(s: number)`: Sets the motor speed.
  - `love.PrismaticJoint.setUpperLimit(upper: number)`: Sets the upper limit.

- `PulleyJoint`: Allows you to simulate bodies connected through pulleys.
  - `love.PulleyJoint.getConstant() -> length: number`: Get the total length of the rope.
  - `love.PulleyJoint.getGroundAnchors() -> a1x: number, a1y: number, a2x: number, a2y: number`: Get the ground anchor positions in world coordinates.
  - `love.PulleyJoint.getLengthA() -> length: number`: Get the current length of the rope segment attached to the first body.
  - `love.PulleyJoint.getLengthB() -> length: number`: Get the current length of the rope segment attached to the second body.
  - `love.PulleyJoint.getMaxLengths() -> len1: number, len2: number`: Get the maximum lengths of the rope segments.
  - `love.PulleyJoint.getRatio() -> ratio: number`: Get the pulley ratio.
  - `love.PulleyJoint.setConstant(length: number)`: Set the total length of the rope. Setting a new length for the rope updates the maximum length values of the joint.
  - `love.PulleyJoint.setMaxLengths(max1: number, max2: number)`: Set the maximum lengths of the rope segments. The physics module also imposes maximum values for the rope segments. If the parameters exceed these values, the maximum values are set instead of the requested values.
  - `love.PulleyJoint.setRatio(ratio: number)`: Set the pulley ratio.

- `RevoluteJoint`: Allow two Bodies to revolve around a shared point.
  - `love.RevoluteJoint.areLimitsEnabled() -> enabled: boolean`: Checks whether limits are enabled.
  - `love.RevoluteJoint.getJointAngle() -> angle: number`: Get the current joint angle.
  - `love.RevoluteJoint.getJointSpeed() -> s: number`: Get the current joint angle speed.
  - `love.RevoluteJoint.getLimits() -> lower: number, upper: number`: Gets the joint limits.
  - `love.RevoluteJoint.getLowerLimit() -> lower: number`: Gets the lower limit.
  - `love.RevoluteJoint.getMaxMotorTorque() -> f: number`: Gets the maximum motor force.
  - `love.RevoluteJoint.getMotorSpeed() -> s: number`: Gets the motor speed.
  - `love.RevoluteJoint.getMotorTorque() -> f: number`: Get the current motor force.
  - `love.RevoluteJoint.getReferenceAngle() -> angle: number`: Gets the reference angle.
  - `love.RevoluteJoint.getUpperLimit() -> upper: number`: Gets the upper limit.
  - `love.RevoluteJoint.hasLimitsEnabled() -> enabled: boolean`: Checks whether limits are enabled.
  - `love.RevoluteJoint.isMotorEnabled() -> enabled: boolean`: Checks whether the motor is enabled.
  - `love.RevoluteJoint.setLimits(lower: number, upper: number)`: Sets the limits.
  - `love.RevoluteJoint.setLimitsEnabled(enable: boolean)`: Enables/disables the joint limit.
  - `love.RevoluteJoint.setLowerLimit(lower: number)`: Sets the lower limit.
  - `love.RevoluteJoint.setMaxMotorTorque(f: number)`: Set the maximum motor force.
  - `love.RevoluteJoint.setMotorEnabled(enable: boolean)`: Enables/disables the joint motor.
  - `love.RevoluteJoint.setMotorSpeed(s: number)`: Sets the motor speed.
  - `love.RevoluteJoint.setUpperLimit(upper: number)`: Sets the upper limit.

- `RopeJoint`: The RopeJoint enforces a maximum distance between two points on two bodies. It has no other effect.
  - `love.RopeJoint.getMaxLength() -> maxLength: number`: Gets the maximum length of a RopeJoint.
  - `love.RopeJoint.setMaxLength(maxLength: number)`: Sets the maximum length of a RopeJoint.

- `Shape`: Shapes are solid 2d geometrical objects which handle the mass and collision of a Body in love.physics. Shapes are attached to a Body via a Fixture. The Shape object is copied when this happens.  The Shape's position is relative to the position of the Body it has been attached to.
  - `love.Shape.computeAABB(tx: number, ty: number, tr: number, childIndex: number) -> topLeftX: number, topLeftY: number, bottomRightX: number, bottomRightY: number`: Returns the points of the bounding box for the transformed shape.
  - `love.Shape.computeMass(density: number) -> x: number, y: number, mass: number, inertia: number`: Computes the mass properties for the shape with the specified density.
  - `love.Shape.getChildCount() -> count: number`: Returns the number of children the shape has.
  - `love.Shape.getRadius() -> radius: number`: Gets the radius of the shape.
  - `love.Shape.getType() -> type: ShapeType`: Gets a string representing the Shape. This function can be useful for conditional debug drawing.
  - `love.Shape.rayCast(x1: number, y1: number, x2: number, y2: number, maxFraction: number, tx: number, ty: number, tr: number, childIndex: number) -> xn: number, yn: number, fraction: number`: Casts a ray against the shape and returns the surface normal vector and the line position where the ray hit. If the ray missed the shape, nil will be returned. The Shape can be transformed to get it into the desired position. The ray starts on the first point of the input line and goes towards the second point of the line. The fourth argument is the maximum distance the ray is going to travel as a scale factor of the input line length. The childIndex parameter is used to specify which child of a parent shape, such as a ChainShape, will be ray casted. For ChainShapes, the index of 1 is the first edge on the chain. Ray casting a parent shape will only test the child specified so if you want to test every shape of the parent, you must loop through all of its children. The world position of the impact can be calculated by multiplying the line vector with the third return value and adding it to the line starting point. hitx, hity = x1 + (x2 - x1) * fraction, y1 + (y2 - y1) * fraction
  - `love.Shape.testPoint(tx: number, ty: number, tr: number, x: number, y: number) -> hit: boolean`: This is particularly useful for mouse interaction with the shapes. By looping through all shapes and testing the mouse position with this function, we can find which shapes the mouse touches.

- `WeldJoint`: A WeldJoint essentially glues two bodies together.
  - `love.WeldJoint.getDampingRatio() -> ratio: number`: Returns the damping ratio of the joint.
  - `love.WeldJoint.getFrequency() -> freq: number`: Returns the frequency.
  - `love.WeldJoint.getReferenceAngle() -> angle: number`: Gets the reference angle.
  - `love.WeldJoint.setDampingRatio(ratio: number)`: Sets a new damping ratio.
  - `love.WeldJoint.setFrequency(freq: number)`: Sets a new frequency.

- `WheelJoint`: Restricts a point on the second body to a line on the first body.
  - `love.WheelJoint.getAxis() -> x: number, y: number`: Gets the world-space axis vector of the Wheel Joint.
  - `love.WheelJoint.getJointSpeed() -> speed: number`: Returns the current joint translation speed.
  - `love.WheelJoint.getJointTranslation() -> position: number`: Returns the current joint translation.
  - `love.WheelJoint.getMaxMotorTorque() -> maxTorque: number`: Returns the maximum motor torque.
  - `love.WheelJoint.getMotorSpeed() -> speed: number`: Returns the speed of the motor.
  - `love.WheelJoint.getMotorTorque(invdt: number) -> torque: number`: Returns the current torque on the motor.
  - `love.WheelJoint.getSpringDampingRatio() -> ratio: number`: Returns the damping ratio.
  - `love.WheelJoint.getSpringFrequency() -> freq: number`: Returns the spring frequency.
  - `love.WheelJoint.isMotorEnabled() -> on: boolean`: Checks if the joint motor is running.
  - `love.WheelJoint.setMaxMotorTorque(maxTorque: number)`: Sets a new maximum motor torque.
  - `love.WheelJoint.setMotorEnabled(enable: boolean)`: Starts and stops the joint motor.
  - `love.WheelJoint.setMotorSpeed(speed: number)`: Sets a new speed for the motor.
  - `love.WheelJoint.setSpringDampingRatio(ratio: number)`: Sets a new damping ratio.
  - `love.WheelJoint.setSpringFrequency(freq: number)`: Sets a new spring frequency.

- `World`: A world is an object that contains all bodies and joints.
  - `love.World.destroy()`: Destroys the world, taking all bodies, joints, fixtures and their shapes with it.  An error will occur if you attempt to use any of the destroyed objects after calling this function.
  - `love.World.getBodies() -> bodies: table`: Returns a table with all bodies.
  - `love.World.getBodyCount() -> n: number`: Returns the number of bodies in the world.
  - `love.World.getCallbacks() -> beginContact: function, endContact: function, preSolve: function, postSolve: function`: Returns functions for the callbacks during the world update.
  - `love.World.getContactCount() -> n: number`: Returns the number of contacts in the world.
  - `love.World.getContactFilter() -> contactFilter: function`: Returns the function for collision filtering.
  - `love.World.getContacts() -> contacts: table`: Returns a table with all Contacts.
  - `love.World.getGravity() -> x: number, y: number`: Get the gravity of the world.
  - `love.World.getJointCount() -> n: number`: Returns the number of joints in the world.
  - `love.World.getJoints() -> joints: table`: Returns a table with all joints.
  - `love.World.isDestroyed() -> destroyed: boolean`: Gets whether the World is destroyed. Destroyed worlds cannot be used.
  - `love.World.isLocked() -> locked: boolean`: Returns if the world is updating its state. This will return true inside the callbacks from World:setCallbacks.
  - `love.World.isSleepingAllowed() -> allow: boolean`: Gets the sleep behaviour of the world.
  - `love.World.queryBoundingBox(topLeftX: number, topLeftY: number, bottomRightX: number, bottomRightY: number, callback: function)`: Calls a function for each fixture inside the specified area by searching for any overlapping bounding box (Fixture:getBoundingBox).
  - `love.World.rayCast(x1: number, y1: number, x2: number, y2: number, callback: function)`: Casts a ray and calls a function for each fixtures it intersects. 
  - `love.World.setCallbacks(beginContact: function, endContact: function, preSolve: function, postSolve: function)`: Sets functions for the collision callbacks during the world update. Four Lua functions can be given as arguments. The value nil removes a function. When called, each function will be passed three arguments. The first two arguments are the colliding fixtures and the third argument is the Contact between them. The postSolve callback additionally gets the normal and tangent impulse for each contact point. See notes. If you are interested to know when exactly each callback is called, consult a Box2d manual
  - `love.World.setContactFilter(filter: function)`: Sets a function for collision filtering. If the group and category filtering doesn't generate a collision decision, this function gets called with the two fixtures as arguments. The function should return a boolean value where true means the fixtures will collide and false means they will pass through each other.
  - `love.World.setGravity(x: number, y: number)`: Set the gravity of the world.
  - `love.World.setSleepingAllowed(allow: boolean)`: Sets the sleep behaviour of the world.
  - `love.World.translateOrigin(x: number, y: number)`: Translates the World's origin. Useful in large worlds where floating point precision issues become noticeable at far distances from the origin.
  - `love.World.update(dt: number, velocityiterations: number, positioniterations: number)`: Update the state of the world.

## Enums

- `BodyType`: The types of a Body. 
  - `static`: Static bodies do not move.
  - `dynamic`: Dynamic bodies collide with all bodies.
  - `kinematic`: Kinematic bodies only collide with dynamic bodies.

- `JointType`: Different types of joints.
  - `distance`: A DistanceJoint.
  - `friction`: A FrictionJoint.
  - `gear`: A GearJoint.
  - `mouse`: A MouseJoint.
  - `prismatic`: A PrismaticJoint.
  - `pulley`: A PulleyJoint.
  - `revolute`: A RevoluteJoint.
  - `rope`: A RopeJoint.
  - `weld`: A WeldJoint.

- `ShapeType`: The different types of Shapes, as returned by Shape:getType.
  - `circle`: The Shape is a CircleShape.
  - `polygon`: The Shape is a PolygonShape.
  - `edge`: The Shape is a EdgeShape.
  - `chain`: The Shape is a ChainShape.

## Examples

### Creating a physics world
```lua
-- Create a physics world
local world = love.physics.newWorld(0, 9.81 * 64, true)  -- gravity: 0, 9.81*64

-- Create a ground body
local ground = love.physics.newBody(world, 400, 550)
local groundShape = love.physics.newRectangleShape(800, 50)
local groundFixture = love.physics.newFixture(ground, groundShape)
```

### Physics object
```lua
-- Create a dynamic physics object
local ballBody = love.physics.newBody(world, 400, 100, "dynamic")
local ballShape = love.physics.newCircleShape(20)
local ballFixture = love.physics.newFixture(ballBody, ballShape, 1)

-- Apply force to the object
ballBody:applyLinearImpulse(100, -500)
```

## Best practices
- Use appropriate physics scale for your game
- Consider performance implications of complex physics simulations
- Handle physics collisions and contacts efficiently
- Test physics behavior on target platforms
- Be mindful of physics accuracy vs performance trade-offs

## Platform compatibility
- **Desktop (Windows, macOS, Linux)**: Full physics support
- **Mobile (iOS, Android)**: Full support but performance may vary
- **Web**: Good support with some limitations
